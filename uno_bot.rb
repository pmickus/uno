#!/usr/bin/ruby

require './uno.rb'
require './irc.rb'

irchash = {"nick"     => "StalUno", 
           "ident"    => "test", 
           "email"    => "heh@heh", 
           "realname" => "Lord of Uno"
}

servers = ['irc.irchighway.net:6668']
channels = ['#lurk-uno']

class Bot
   def initialize
      @irc  = nil     
      @uno  = UNO.new
   end
   def start(server, port, irchash, channels)
      @irc = IRC.new(server, port, irchash)
      @irc.connect
      if !(@irc.sock.nil?)
          @irc.signon
          for channel in channels
             if channel.scan(" ")
               newchan = channel.split(" ")
               chan = Channel.new(newchan[0], newchan[1]) 
             else   
               chan = Channel.new(channel, nil)
             end
             @irc.channels.push(chan)  
          end      
      end    
   end
   def nick_update(nick, host, newnick)
      for game in @uno.games
         player = game.find_player(host)
         if !(player.nil?)
            player.nick = newnick
         end
      end
   end    
   def do(io)
      if io.kind == "server"
        case io.hash['num']
           # nick in use
           when 433 then 
              @irc.nick = @irc.nick + "_"
              @irc.set_nick
           # motd
           when 376 then
              @irc.mass_join
              puts "heh"   
           # names
           when 353 then
              recv = io.hash['msg']
              chan = recv.scan(/#\S+/)
              names = recv.scan(/:.*/)
              names = names.join.sub(/:/, "") 
              co = @irc.find_chan(chan.join)
              co.state = "joined"
              if !(co.nil?)
                 co.names = names.split(" ")
                 #co = @irc.find_chan(chan.to_s)     
              else
                 puts "Received a NAMES from a channel not added to list"
              end               
        end
      elsif io.kind == "serverping"
         @irc.pong(io.hash['target']) 
      elsif io.kind == "kick"
         @irc.kick(io.hash['target'], io.hash['channel'])  
      elsif io.kind == "nick"
         nick_update(io.hash['nick'], io.hash['host'], io.hash['newnick']) 
      elsif io.kind == "privmsg"
         # channel traffic  
         case io.hash['target']
            when /^#/  then
               case io.hash['msg']
                  when /^(!|p|d|c|h|u)/i then
                     @uno.parse(io)
               end 
            when @irc.nick
                case io.hash['msg']
                   #version
                   when "\001VERSION\001"
                      @irc.send_version(io.hash['nick'])
                   when /^\001PING/
                      @irc.ping_reply(io.hash['nick'], io.hash['msg'])
                end   
         end  
      end           
   end
   def tick
      for game in @uno.games
	     if game.state == "join"
		    t = (Time.now - game.time)
			if t >= 300
			   if game.players.size >= 2
                  @uno.begin_uno(game, game.players[0].host)
               else
			      msg = "Not enough players."
				  @uno.uno_io(msg, game.channel, "privmsg") 
                  @uno.cancel(game)
               end
            end
         end	
         if game.state == "color"
            t = (Time.now - game.lastplay)
			for player in game.players
                if player.state == "color"
                   cp = player
                end
            end				
            if t >= 60 and t <= 180 and game.turn.warn == 0
			   game.turn.warn = 1
               msg = "#{cp.nick}, if you do not select a color in #{(180 - t.floor)} seconds a random color will be picked for you."
               @uno.uno_io(msg, game.channel, "privmsg")
			elsif t >= 180
			   ccard = Card.new(nil, nil, nil, nil)
			   rr = rand(4)
			   case rr
			      when 0
				     cmsg = "color red"
					 ccard.color = "red"
					 ccard.special = "RED"
				  when 1
				     cmsg = "color blue"
					 ccard.color = "blue"
					 ccard.special = "BLUE" 
                  when 2
				     cmsg = "color green"
					 ccard.color = "green"
					 ccard.special = "GREEN" 
                  when 3
				     cmsg = "color yellow"
					 ccard.color = "yellow"
					 ccard.special = "YELLOW"
               end 		 
               msg = "#{cp.nick}, time is up! You magically choose #{UNO.color_card(ccard)}."
               @uno.uno_io(msg, game.channel, "privmsg") 			   
               @uno.select_color(game, cp.nick, cp.host, cmsg)				      			
            end
         end    			
         if game.state != "join" and game.state != "color"
            t = (Time.now - game.lastplay)           
            case t
               when 60..119
                  if game.turn.warn < 1
                     game.turn.warn = 1
                     msg = "#{game.turn.nick}, if you do not play in #{(180 - t.floor)} seconds you will be removed from the current game."
                     @uno.uno_io(msg, game.channel, "privmsg")
                  end
               when 120..180
                  if game.turn.warn < 2
                     game.turn.warn = 2
                     msg = "#{game.turn.nick}, if you do not play in #{(180 - t.floor)} seconds you will be removed from the current game."
                     @uno.uno_io(msg, game.channel, "privmsg")
                  end    
               when 180..10000
                  msg = "#{game.turn.nick} has not played for over 3 minutes."
                  @uno.uno_io(msg, game.channel, "privmsg")
                  @uno.kick(game, game.turn.host)
            end
         end
      end                 
   end 
   attr_reader :irc, :uno   
end

if ARGV[0].eql?("-b")
   daemon = true
   pid = Process.pid
   Process.detach(pid)
   puts "Running in background and detaching. PID: #{pid}" 
else
   daemon = false
end

if servers.length == 0
   exit
end

bot = Bot.new
n = 0
loop do
   sa = servers[n].split(":") 
   bot.start(sa[0], sa[1].to_i, irchash, channels)   
   until bot.irc.sock.nil?
      recv = String.new
      res = select([bot.irc.sock], nil, nil, 1)
      if !(res.nil?) 
         for inp in res[0]
            if inp == bot.irc.sock 
               recv = bot.irc.gets
            end
         end
      end   
      if !(recv.nil?)  	  
         if !(recv.empty?)
            if !(daemon) 
               puts recv
            end 
            io = IRC.parse(recv)
            if !(io.nil?)
               bot.do(io)
            end 
         end
         if !(bot.uno.cmds.empty?)
            for cmd in bot.uno.cmds
                bot.irc.io_send(cmd)
            end
            bot.uno.cmds.clear   
         end 
         if !(daemon)
            for msg in bot.irc.sendq
                puts msg
            end
         end
		 bot.tick
         bot.irc.puts 
	  end
   end
   if n == (servers.length - 1)
      n = 0
   else
      n += 1
   end
   sleep 10
end
