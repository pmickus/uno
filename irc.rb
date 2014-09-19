require 'socket'

class IRC
   def initialize(server, port, irchash)
      @server    = server
      @port      = port
      @nick      = irchash['nick']
      @ident     = irchash['ident']
      @email     = irchash['email']
      @realname  = irchash['realname'] 
      @channels  = Array.new 
      @sendq     = Array.new    
      @sock      = nil
      @penalty   = 0 
      @lastsend  = Time.now
   end  
   def connect
      begin  
         @sock = TCPSocket.new(@server, port)
      rescue
         @sock.close
         @sock = nil 
      ensure 
      end  
   end
   def gets
      begin
        @sock.gets
      rescue 
        @sock.close
        @sock = nil
      ensure
      end
   end
   def puts
      begin
         if !(@sendq.empty?)
            if (Time.now - @lastsend) >= 2
               @penalty = 0
            end 
            for msg in @sendq
                @sock.puts(msg + "\n")
                @lastsend = Time.now
                if msg.length >= 160
                   @penalty += 2
                else
                   @penalty += 1
                end 
                if @penalty >= 3
                   sleep 1
                   @penalty = 0
                end 
            end
         end
       rescue
         @sock.close
         @sock = nil
       ensure   
         @sendq.clear 
       end 
   end  
   def sendnow(msg)
      begin
         @sock.puts(msg + "\n")
      rescue
         @sock.close
         @sock = nil
      end 
   end  
   def append_sendq(msg)
      @sendq.push(msg)
   end       
   def privmsg(targ, msg)
      append_sendq("PRIVMSG #{targ} :#{msg}")
   end  
   def notice(targ, msg)
      append_sendq("NOTICE #{targ} :#{msg}")
   end
   def pong(targ)
      sendnow("PONG #{targ}")
   end    
   def set_nick
      append_sendq("NICK #{@nick}")
   end
   def send_version(nick)
      sendnow("NOTICE #{nick} :\001VERSION mIRC v6.12 Khaled Mardam-Ghey\001")
   end
   def ping_reply(nick, msg)
      sendnow("NOTICE #{nick} :#{msg}")
   end    
   def register(ident, email, hostname, realname)
      append_sendq("USER #{ident} #{email} #{hostname} :#{realname}")
   end  
   def signon
      email = @email.split("@")        
      self.set_nick         
      register(@ident, email[0], email[1], @realname)
   end 
   def kick(targ, chan)
      if targ == @nick
         channel = find_chan(chan)
         if channel.nil?
            puts "I just got kicked from a channel that was not added!"
            return
         end
         @channels.delete(chan)
         join(chan)
      end
   end 
   def mass_join
      for channel in @channels 
         if !(channel.key.nil?)
            append_sendq("JOIN #{channel.channel} #{channel.key}")          
         else   
            append_sendq("JOIN #{channel.channel}")
         end
      end    
   end
   def join(channel)
      if channel.scan(" ")
         newchan = channel.split(" ")
         append_sendq("JOIN #{newchan[0]} #{newchan[1]}")
         chan = Channel.new(newchan[0], newchan[1]) 
      else   
         append_sendq("JOIN #{channel}")
         chan = Channel.new(channel, nil)
      end
      @channels.push(chan)  
   end   
   def find_chan(chan)
       for channel in @channels
          if chan == channel.channel
             return channel
          end
       end
       nil           
   end 
   def io_send(cmd)
      msg = cmd.hash['msg']
      blocks = (msg.length / 512.to_f).ceil
      b = 0  
      1.upto(blocks) { |n|
          buf = msg[b, (n*512) - 1] 
          case cmd.kind
             when "privmsg"
                privmsg(cmd.hash['target'], buf)
             when "notice"
                notice(cmd.hash['target'], buf)
          end
          b += 512
      }
   end         
   def IRC.parse(recv)
      cmd = case recv
         # server message
         when /:[a-z0-9\.\-\_]+\s\d+\s.*\s:/i then IRC.server_parse(recv)
         # server ping
         when /^PING/ then IRC.server_ping_parse(recv)
         # kick
         when /:.*\sKICK\s.*:/i then IRC.kick_parse(recv)
         # privmsg
         when /:.*\sPRIVMSG/i then IRC.privmsg_parse(recv)
         # nick change
         when /:.*\sNICK\s.*:/i then IRC.nick_parse(recv) 
         else nil
      end
   end 
   def IRC.nick_parse(recv)
      #get nick
      nick = recv.scan(/:.*?!/)
      if nick.length > 1
         nick.delete(nick[1])
      end  
      nick = nick.join
      recv = recv.sub(nick, "")
      nick = nick.gsub(/!/, "")
      nick = nick.gsub(/:/, "")
      #get host 
      host = recv.scan(/^.*?\s(?=n)/i)
      host = host.join.strip
      recv = recv.sub(host, "") 
      #get new nick
      newnick = recv.scan(/:\w+/)
      newnick = newnick.join
      newnick = newnick.sub(/:/, "")

      hash = Hash["nick" => nick, "host" => host, "newnick" => newnick]
      ircobj = IRCObject.new("nick", hash) 
   end
   def IRC.kick_parse(recv)
      #get nick
      nick = recv.scan(/:.*?!/)
      if nick.length > 1
         nick.delete(nick[1])
      end  
      nick = nick.join
      recv = recv.sub(nick, "")
      nick = nick.gsub(/!/, "")
      nick = nick.gsub(/:/, "")
      #get host 
      host = recv.scan(/^.*?\s(?=k)/i)
      host = host.join.strip
      recv = recv.sub(host, "") 
      #get channel
      recv = recv.sub(/KICK/i, "")         
      recv = recv.strip
      chan = recv.scan(/^#\w+/)
      chan = chan.join 
      recv = recv.sub(chan, "")
      recv = recv.strip        
      #get target
      target = recv.scan(/^\w+/)
      target = target.join
      recv = recv.strip 
      #get msg
      msg = recv.scan(/:.*/)
      msg = msg.join
      recv = recv.sub(msg, "")
      msg = msg.sub(/:/, "")
 
      hash = Hash["nick" => nick, "host" => host, "channel" => chan, "target" => target, "kickmsg" => msg]
      ircobj = IRCObject.new("kick", hash)
   end   
   def IRC.server_ping_parse(recv)
      servname = recv.scan(/:[a-z0-9\.\-]+/i)
      servname = servname.join
      recv = recv.sub(servname, "")
      servname = servname.strip
      servname = servname.sub(/:/, "") 

      hash = Hash["target" => servname]               
      ircobj = IRCObject.new("serverping", hash) 
   end
   def IRC.server_parse(recv)
  
      # get server name
      servname = recv.scan(/^:[a-z0-9\.\-]+\s/i)
      servname = servname.join
      recv = recv.sub(servname, "")
      servname = servname.strip
      servname = servname.sub(/:/, "") 
      # get num
      servnum = recv.scan(/^\d+/)
      servnum = servnum.join
      recv = recv.sub(servnum, "")
          
      hash = Hash["name" => servname, "num" => servnum.to_i, "msg" => recv]
                 
      ircobj = IRCObject.new("server", hash) 

      return ircobj     
   end          
   def IRC.privmsg_parse(recv)
      #get nick
      nick = recv.scan(/:.*?!/)
      if nick.length > 1
         nick.delete(nick[1])
      end  
      nick = nick.join
      recv = recv.sub(nick, "")
      nick = nick.gsub(/!/, "")
      nick = nick.gsub(/:/, "")
      #get host 
      host = recv.scan(/^.*?\s(?=p)/i)
      host = host.join.strip
      recv = recv.sub(host, "") 
      #get msg
      recv = recv.sub(/PRIVMSG/i, "")         
      recv = recv.strip
      msg = recv.scan(/:.*/)
      msg = msg.join
      recv = recv.sub(msg, "")
      msg = msg.sub(/:/, "")
      #target
      target = recv.strip 
       
      hash = Hash["nick" => nick, "host" => host, "target" => target, "msg" => msg]
                 
      ircobj = IRCObject.new("privmsg", hash)  
       
      return ircobj
   end        
   attr_reader :server, :port, :sock, :nick, :channels, :sendq, :lastsend
   attr_writer :nick, :channels, :lastsend
end

class Channel
   def initialize(chan, key)
      @channel = chan
      @key     = key
      @names   = Array.new
      @state   = nil
   end 
   def find_name(nick)
      for name in @names
          if !(name.scan(nick).empty?)
             return name
          end
      end
      nil
   end    
   attr_reader :channel, :key, :names, :state
   attr_writer :names, :state 
end

class IRCObject
   def initialize(kind, hash)
      @kind = kind
      @hash = hash
   end
   attr_reader :kind, :hash
end
