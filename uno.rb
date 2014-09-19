require 'strscan'

class Card
   def initialize(color, number, honor, special)
      @color   = color
      @number  = number
      @honor   = honor
      @special = special
   end
   def cmp(card)
      if card.color == @color and card.number == @number and card.honor == @honor and card.special == @special
         true
      else
         false
      end 
   end
   attr_reader :color, :number, :honor, :special
   attr_writer :color, :number, :honor, :special 
end

class Deck
   def initialize
      @cards = Array.new
   end
   def append(card)
      @cards.push(card)
      self
   end
   def delete(card)
      @cards.delete(card)
   end
   def delete_first
      @cards.shift
   end
   def delete_last
      @cards.pop
   end
   def delete_one(card)
      i = @cards.index(card)
      if i.nil?
         return nil
      end 
      @cards.delete_at(i)  
   end  
   def find(findme)
       for card in @cards
          if card.cmp(findme)  
             return card
             break
          end 
       end 
       nil  
   end      
   def prepend(card)
      @cards.unshift(card)
   end  
   def [](index)
      @cards[index]
   end
   def size
      @cards.length
   end 
   def sort
      @cards.sort { |x,y| x.color.to_s + x.number.to_s <=> y.color.to_s + y.number.to_s }
   end     
   def top
      @cards[0]
   end
   def swap!(a,b)
      c = @cards[a]
      @cards[a] = @cards[b]
      @cards[b] = c
   end
   def shuffle
      (size-1).downto(1) { |n| swap!(n, rand(size)) }   
   end
   def fill
      colors = ["red", "blue", "green", "yellow"]
      honors = ["Reverse", "Skip", "Draw Two"]
      specials = ["WILD", "WILD DRAW FOUR"]      
      for color in colors
         (1..9).each do |n|
            card = Card.new(color, n.to_s, nil, nil)
            self.append(card)
            self.append(card)
         end
         card = Card.new(color, "0", nil, nil)
         self.append(card)
         for honor in honors
            card = Card.new(color, nil, honor, nil)
            self.append(card)
            self.append(card)
         end 
      end
      for special in specials
         card = Card.new(nil, nil, nil, special)
         self.append(card)
         self.append(card)
         self.append(card)
         self.append(card)
      end
   end
   def clear
      @cards.clear
   end 
   def num_of(findme)
      num = 0
      @cards.each{ |card|
         if card == findme
            num += 1
         end
      }
      return num
   end     
   attr_reader :cards 
   attr_writer :cards
end


class Player
   def initialize(nick, host)
      @nick    = nick
      @host    = host
      @hand    = Deck.new
      @state   = "none" 
      @has_uno = false
      @warn    = 0  
      @times   = Array.new
   end
   attr_reader :host, :nick, :hand, :state, :has_uno, :warn, :times
   attr_writer :nick, :hand, :state, :has_uno, :warn, :times 
end

class Game
   def initialize(channel)
      @channel  = channel
      @deck     = Deck.new
      @pile     = Deck.new
      @players  = Array.new
      @state    = String.new
      @round    = 0
      @stop     = Array.new
      @rules    = 0 
      @turn     = nil
      @time     = Time.now
      @unos     = 0
      @calluno  = 1
      @lastplay = Time.now
   end
   def start
      @deck.fill
      @deck.shuffle
      @deck.shuffle
      @state = "deal"
   end
   def deal
      if @state == "deal"
         (1..7).each {|n|
            for player in @players
                player.hand.prepend(@deck.top)
                @deck.delete_first
            end 
         }  
         @state = "game"             
      else
         nil
      end
   end
   def add_pile
      @pile.prepend(@deck.top)
      @deck.delete_first
      @pile.top
   end  
   def add_player(nick, host)
      player = Player.new(nick, host)
      @players.push(player)
   end
   def find_player(host)
      for player in @players
          if player.host == host
             return player
          end
      end
      nil
   end  
   def reverse
      @players = @players.reverse
   end
   def skip
      self.turn.state = "none" 
      self.next_turn
   end 
   def next_turn
      if @turn.nil?
         @turn = @players[0]
      else
         n = @players.index(@turn)
         if n + 1 == @players.length
            @turn = @players[0]
         else
            @turn = @players[n+1]
         end
      end
   end
   def prev_player
      if @turn.nil?
         return nil
      end 
      n = @players.index(@turn)
      if n == 0
         return @players[@players.length - 1]
      else
         return @players[n-1]
      end
   end  
   def next_player
      if @turn.nil? 
         return nil
      end 
      n = @players.index(@turn)
      if n + 1 == @players.length
         return @players[0]
      else
         return @players[n+1]
      end
   end
     
attr_reader :channel, :deck, :pile, :players, :state, :round, :turn, :rules, :stop, :time, :unos, :calluno, :time, :lastplay 
attr_writer :deck, :pile, :players, :state, :round, :turn, :rules, :stop, :unos, :calluno, :lastplay, :time 
end

class UNO
   def initialize
      @games = Array.new
      @cmds  = Array.new 
   end 
   def newgame(channel)
      if !(find_game(channel).nil?)
         return
      end  
      game = Game.new(channel)
      game.state = "join" 
      @games.push(game)
      msg = "A new game of UNO is starting type !join to join"
      uno_io(msg, game.channel, "privmsg")
      msg = "When ready type !begin to begin game. There must be at least two players to begin. Game will automatically start in 5 minutes."
      uno_io(msg, game.channel, "privmsg")
      msg = "Type !cancel to cancel this game."
      uno_io(msg, game.channel, "privmsg")  
      msg = "Type !modify to play a game with modified rules."
      uno_io(msg, game.channel, "privmsg")
      msg = "Type !calluno to unset the Call UNO rule."
      uno_io(msg, game.channel, "privmsg")
   end
   def find_game(channel)
       for game in @games
          if game.channel == channel
             return game
          end
       end
       nil
   end 
   def uno_io(msg, channel, kind)
       cmsg = "\0030,1#{msg}"
       hash = Hash["target" => channel, "msg" => cmsg]
       io = IRCObject.new(kind, hash)
       @cmds.push(io)
   end     
   def parse(io)
      if io.hash['msg'] == "!unostart"
         newgame(io.hash['target'])
         return 
      end    
      game = find_game(io.hash['target'])
      if !(game.nil?) 
         case io.hash['msg']
            when /^(!|d|c|pass|pile|hand|uno)/i then
               parse_cmd(io.hash, game)
            when /^p/i then
               parse_play(io.hash, game)            
         end
         if game.state == "end" 
            @games.delete(game)
         end
         return 
      end
      return 
   end   
   def join(game, nick, host)
       if game.state == "join"
          if game.find_player(host).nil?
             game.add_player(nick, host)
             msg = "#{nick} has joined the game. There are #{game.players.length} player(s)."
          else
             msg = "#{nick}, you have already joined!"
          end  
          uno_io(msg, game.channel, "privmsg")
       else
          if game.find_player(host).nil?
             late_join(game, nick, host)
          end  
       end                 
   end
   def kick(game, host)
       player = game.find_player(host)
       if player.nil?
          return
       end
	   game.lastplay = Time.now
       for card in player.hand.cards
          game.pile.append(card)
          player.hand.delete(card)
       end
       msg = "#{player.nick} has been removed from the current game."
       uno_io(msg, game.channel, "privmsg")
       if game.players.length == 2
          msg = "Current game has been stopped"
          uno_io(msg, game.channel, "privmsg")
          @games.delete(game)
       else
          msg = "#{player.nick}'s cards have been added to the bottom of the pile."
          uno_io(msg, game.channel, "privmsg") 
          turn(game)
          game.players.delete(player) 
       end      
   end  
   def cancel(game)
       if game.state == "join"
          msg = "Current game has been cancelled."
          @games.delete(game) 
          uno_io(msg, game.channel, "privmsg")
       else
          msg = "Game has already started you may type !unostop to stop current game."
          uno_io(msg, game.channel, "privmsg")
       end
   end 
   def unostop(game, nick, host)
      if game.state == "join"
         msg = "You may stop the game with !cancel"
         uno_io(msg, game.channel, "privmsg")
         return
      end
      player = game.find_player(host)
      if player.nil?
         msg = "Sorry #{nick}, only current players can stop the game."
         uno_io(msg, game.channel, "privmsg")
         return
      end
      if game.stop.length == 0
         game.stop.push(player.host)
         msg = "#{nick} has requested to stop the current game. To cancel your request type !unostop again."
         uno_io(msg, game.channel, "privmsg")
         msg = "One more player must type !unostop to stop the current game."
         uno_io(msg, game.channel, "privmsg")             
      elsif game.stop.length == 1
         if game.stop[0] == player.host
            msg = "#{nick}, cancelling your request to stop the game."
            uno_io(msg, game.channel, "privmsg")
            game.stop.delete(player.host)
         else
           @games.delete(game) 
            msg = "Cancelling the current game."  
            uno_io(msg, game.channel, "privmsg") 
         end
      end  
   end
   def UNO.color_card(card)
       color = "#{card.color} #{card.number}#{card.honor}#{card.special}"
       color = color.sub("yellow", "\0038")
       color = color.sub("red", "\0034")
       color = color.sub("blue", "\00312") 
       color = color.sub("green", "\0033")
       color = color.sub("WILD", "\0034W\0033I\00312L\0038D")
       color = color.sub("DRAW", "\0034D\0033R\00312A\0038W")
       color = color.sub("FOUR", "\0034F\0033O\00312U\0038R")
       msg = "\0030[#{color} \0030]"
       return msg
   end
   def hand(game, nick, host)
       if game.state == "game" or game.state == "color"
          player = game.find_player(host)
          if player.nil?
             return
          end  
          msg = "Current Hand: " 
          if player.hand.size < 20
             player.hand.sort.each { |c| msg << "#{UNO.color_card(c)} " }
             msg = msg.strip
             uno_io(msg, nick, "notice")
          else
             player.hand.cards = player.hand.sort 
             blocks = (player.hand.size / 20.to_f).ceil
             b = 0 
             1.upto(blocks) { |n|
                player.hand.cards[b, 19].each { |c| msg << "#{UNO.color_card(c)}" }
                msg = msg.strip 
                uno_io(msg, nick, "notice")
                msg = String.new
                b += 19
             } 
          end
       else    
          msg = "Game has not started yet. Type !begin to begin."
          uno_io(msg, game.channel, "privmsg")
       end  
   end    
   def count(game)
      if game.state == "game" or game.state == "color"
         msg = String.new
         game.players.each { |p| 
         if p == game.turn
            msg << "\0036>>\0030,1#{p.nick}(\00312#{p.hand.size}\0030)\0036<<\0030,1 "
         else 
            msg << "#{p.nick}(\00312#{p.hand.size}\0030,1) "
         end
         }
         msg = msg.strip
         uno_io(msg, game.channel, "privmsg")
      else
         msg = "Game has not started yet!"
         uno_io(msg, game.channel, "privmsg") 
      end
   end    
   def pile(game)
      if game.state == "game"
	     n = 0
	     game.pile.cards.each { |card| 
		 if !(card.special =~ /(red|blue|green|yellow)/i)
            n += 1
         end			
		 } 
         msg = "Top Card: \002#{UNO.color_card(game.pile.top)}\002 , #{n} card(s) in pile"
         uno_io(msg, game.channel, "privmsg")
      else
         msg = "Game has not started yet!" 
         uno_io(msg, game.channel, "privmsg")  
      end
   end
   def deck(game)
      if game.state == "game"
         msg = "The current deck has #{game.deck.size} card(s) left!"
         uno_io(msg, game.channel, "privmsg")
      else
         msg = "Game has not started yet!"
         uno_io(msg, game.channel, "privmsg")
      end  
   end        
   def turn(game)
        
       if game.deck.size == 0
          reshuffle(game)
       end
       if game.round > 1
          game.turn.state = "none" 
       end  
        
       game.next_turn
       game.turn.state = "turn"
       msg = "It is \0037#{game.turn.nick}\0030's turn. The card in play is \002 = #{UNO.color_card(game.pile.top)} =\002" 
       uno_io(msg, game.channel, "privmsg")
       if game.round > 1 
          hand(game, game.turn.nick, game.turn.host)
       end
       if (game.round - game.unos) == 1
          game.players.each { |p|  
             if p.has_uno
                p.has_uno = false
             end
          }
       end   
       game.round += 1                     
   end      
   def endgame(game) 
      timesecs = Time.now - game.time 
      mins  = (timesecs / 60).floor
      secs  = (timesecs - (mins * 60)).floor
      msecs = ((timesecs - ((mins * 60) + secs)) * 1000).ceil
      msg = "Congratulations #{game.turn.nick}! You have won the game! Game time: #{mins}m#{secs}s#{msecs}ms"
      uno_io(msg, game.channel, "privmsg")  
      game.state == "end"  
      @games.delete(game)
      
   end         
   def rules(game, host)
      player = game.find_player(host)
      if player.nil?
         return
      end 
      if game.state == "join"
        if game.rules == 0
           game.rules = 1
           msg = "Now playing with modified rules (Jump-in Rule, Infinite draw, Multiple cards). Type !modify to revert to standard rules."
           uno_io(msg, game.channel, "privmsg")
        elsif game.rules == 1
           game.rules = 0
           msg = "Now playing with standard rules."
           uno_io(msg, game.channel, "privmsg")
        end
      else 
           msg = "You may not change the rules at this time."
           uno_io(msg, game.channel, "privmsg")
      end
   end    
   def begin_uno(game, host)
      player = game.find_player(host)
      if player.nil?
         return
      end 
      if game.state == "join"
         if game.players.length >= 2
            game.time = Time.now
			game.lastplay = Time.now
            game.start
            game.deal
            # make sure top card is not a honor or special
            msg = "Starting game! Shuffling deck and dealing cards."
            uno_io(msg, game.channel, "privmsg") 
            cc = game.add_pile 
            until !(cc.color.nil?) and !(cc.number.nil?)
               game.deck.append(cc)
               game.pile.delete_first
               cc = game.add_pile
            end                    
            count(game)
            for player in game.players
                hand(game, player.nick, player.host)
            end
            turn(game)  
        end
      end
   end
   def reshuffle(game)
      game.pile.cards.delete_if { |card| card.special =~ /(red|blue|green|yellow)/i }
   
      cc = game.pile.top
      game.pile.delete_first
      game.pile.cards.each { |c| game.deck.append(c) }  
      game.pile.clear
      game.pile.prepend(cc) 
      game.deck.shuffle
      game.deck.shuffle
      msg = "The deck has been exhausted. Adding pile to deck and reshuffling."
      uno_io(msg, game.channel, "privmsg")
      deck(game)
   end
   def draw(game, nick, host, num, kind) 
       if game.state == "color" or game.state == "join"
          return
       end
       player = game.find_player(host)
       if player.nil?
          return nil
       end 
       if game.deck.size == 0
          reshuffle(game)
       end
       if kind == "draw"
          if player.state == "turn"
             card = game.deck.top               
             player.hand.append(card)
             game.deck.delete_first
             msg = "\00312#{nick}\0030,1, drew a card."
             uno_io(msg, game.channel, "privmsg")  
             msg = "You drew a #{UNO.color_card(card)}"
             uno_io(msg, nick, "notice")
             player.state = "draw"        
          elsif game.rules > 0 and player.state == "draw"
             for card in player.hand.cards
                 if UNO.match(game, card)
                    msg = "#{nick}, you have a #{UNO.color_card(card)} that may be played!"
                    uno_io(msg, game.channel, "privmsg")
                    pcards = Deck.new
                    pcards.append(card)
                    play(game, player, pcards)
                    return
                 end
             end
             card = game.deck.top               
             player.hand.append(card)
             game.deck.delete_first
             msg = "\00312#{nick}\0030,1, drew a card."
             uno_io(msg, game.channel, "privmsg")  
             msg = "You drew a #{UNO.color_card(card)}"
             uno_io(msg, nick, "notice")
             player.state = "draw"    
          else    
             return nil  
          end
       elsif kind == "penalty"
          cards = String.new
          1.upto(num) { |n|
             card = game.deck.top
             player.hand.append(card)
             game.deck.delete_first 
             cards << "#{UNO.color_card(card)} "
             if game.deck.size == 0
                reshuffle(game)
             end      
          }
          msg = "\00312#{nick}\0030,1, drew \002#{num}\002 card(s)."
          uno_io(msg, game.channel, "privmsg") 
          msg = "You drew #{cards}"
          uno_io(msg, player.nick, "notice")
       
       end                  
   end
   def skip(game, player)
      game.skip
      msg = "\00312#{player.nick}\0030,1 has been skipped!"
      uno_io(msg, game.channel, "privmsg")
   end 
   def UNO.match(game, card)
       cc = game.pile.top
       if card.special == "WILD" or card.special == "WILD DRAW FOUR"
          return true
       elsif !(cc.special.nil?)
         if cc.color == card.color
            return true
         else
            return false
         end
       elsif !(cc.honor.nil?)
         if cc.color == card.color or cc.honor == card.honor
            return true
         else
            return false
         end
       elsif !(cc.number.nil?)
         if cc.number == card.number or cc.color == card.color 
            return true
         else
            return false
         end
       end 
   end  
   def UNO.match_multi(game, cards)         
       0.upto(cards.size - 2) { |n|
           if !(cards[n].special.nil?) or !(cards[n+1].special.nil?)           
              return false
           elsif cards[n].honor.nil? 
              unless cards[n].number == cards[n+1].number
                return false
              end
           elsif cards[n].number.nil?
              unless cards[n].honor == cards[n+1].honor
                return false
              end              
           end
       }
   end             
   def reverse(game)
      game.reverse
      msg = "Order has been reversed!"
      count(game)
      uno_io(msg, game.channel, "privmsg")
      if game.players.length == 2
         np = game.next_player
         skip(game, np)
      end
   end   
   def wild(game, player)
      player.state = "color"
      wildcard = Card.new(nil, nil, nil, nil)
      game.pile.prepend(wildcard)   
      game.state = "color"
      msg = "Please select a color with !color"
      uno_io(msg, game.channel, "privmsg")
   end
   def wd4(game, player)
      np = game.next_player
      draw(game, np.nick, np.host, 4, "penalty")  
      skip(game, np)
      wild(game, player)
   end 
   def select_color(game, nick, host, msg)
      player = game.find_player(host)
      if player.nil? 
         return
      elsif player.state != "color"
         return
      end
    
	  player.warn = 0
	  
      msg = msg.sub(/!?color/, "")
      msg = msg.strip
     
      case msg
         when /^(red|r)/i then c = "red"
         when /^(blue|b)/i then c = "blue"
         when /^(yellow|y)/i then c = "yellow"
         when /^(green|g)/i then c = "green"
         else return
      end 
      game.pile.top.color = c
      game.pile.top.special = c.upcase
      game.state = "game"
      player.state = "none"
      game.lastplay = Time.now
      turn(game)
   end  
   def set_call_uno(game, host)
      player = game.find_player(host)
      if player.nil?
         return
      end
      if game.state == "join"
         if game.calluno == 1
            game.calluno = 0
            msg = "Calling UNO has been disabled."
            uno_io(msg, game.channel, "privmsg")
         elsif game.calluno == 0
            game.calluno = 1  
            msg = "Calling UNO has been enabled."
            uno_io(msg, game.channel, "privmsg")
         end
      else
          msg = "You may not change the rules at this time."
          uno_io(msg, game.channel, "privmsg")  
      end
   end
   def call_uno(game, nick, host)
      if game.state == "join" or game.unos == game.round or game.calluno == 0
          return 
      end 
      player = game.find_player(host)
      if player.nil?
         return
      end
      someone_has_uno = false
      if player.has_uno 
        msg = "#{nick} has \0038U\00312N\0034O\0030,1!"
        uno_io(msg, game.channel, "privmsg")
        player.has_uno = false
        someone_has_uno = true
      else
        game.players.each { |p|  
           if p.has_uno
              msg = "#{p.nick}, had \0038U\00312N\0034O\0030,1 but did not call !uno and therefore must draw 2 cards!"
              uno_io(msg, game.channel, "privmsg")
              draw(game, p.nick, p.host, 2, "penalty")
              p.has_uno = false
              someone_has_uno = true
           end
        }     
      end
      if !(someone_has_uno)
         msg = "#{player.nick}, nobody has \0038U\00312N\0034O\0030,1! You must draw a card for being a retard."
         uno_io(msg, game.channel, "privmsg")
         draw(game, player.nick, player.host, 1, "penalty")
      end
      game.unos = game.round
   end   
   def late_join(game, nick, host)
      game.add_player(nick, host)
      player = game.find_player(host)
      if player.nil?
         return
      end
      if game.deck.size == 0
         reshuffle(game)
      end
      (1..7).each {|n|
          player.hand.prepend(game.deck.top)
          game.deck.delete_first
          if game.deck.size == 0
             reshuffle(game)
          end
      }  
      msg = "#{player.nick}, has joined the game!"
      uno_io(msg, game.channel, "privmsg")
      count(game)
      hand(game, player.nick, player.host)
   end 
   def pass(game, nick, host)
       if game.state == "color" or game.state == "join"
          return 
       end 
       player = game.find_player(host)
       if player.nil?
          return nil
       end  
       if player.state != "draw" and player.state != "turn"
          return nil
       end
	   game.lastplay = Time.now
       if game.rules > 0 
          msg = "#{nick}, you may not pass with Infinite Draw!"
          uno_io(msg, game.channel, "privmsg")
          return 
       elsif player.state == "draw"
          msg = "#{nick}, has passed!"
          player.state = "none"
          uno_io(msg, game.channel, "privmsg")
          turn(game)
       elsif player.state == "turn"
          msg = "#{nick}, you must draw a card first!"
          uno_io(msg, game.channel, "privmsg") 
       end
   end      
   def play(game, player, pcards)
      draws   = 0
      revs    = 0
      skips   = 0
      
      player.warn = 0
      if player.state != "draw" and game.round > 1
         player.times.push((Time.now - game.lastplay).round)
      end  
      game.lastplay = Time.now

      #if !(player.times.empty?)
      #   puts player.times.join(" ")
      #end
        
      msg = "#{player.nick} plays "
      pcards.cards.each { |card|
            tmp = player.hand.find(card)
            msg << "#{UNO.color_card(tmp)}" 
            game.pile.prepend(tmp)
            player.hand.delete_one(tmp)
      }      
      uno_io(msg, game.channel, "privmsg")

      if player.hand.size == 0
         endgame(game)
         return
      elsif player.hand.size == 1 and game.calluno == 1
         player.has_uno = true
         game.unos = game.round
      end

      if !(pcards[0].special.nil?)
         if pcards[0].special == "WILD"
            wild(game, player) 
            return        
         elsif pcards[0].special == "WILD DRAW FOUR"
            wd4(game, player)
            return 
         end
      end
      for card in pcards.cards          
         if card.honor == "Draw Two" 
            draws += 2
         elsif card.honor == "Reverse"
            revs += 1
         elsif card.honor == "Skip"
            skips += 1
         end
      end

      if revs & 1 != 0 
         reverse(game)
      elsif revs > 0
         msg = "Even number of reverses played cancel each other out!"
         uno_io(msg, game.channel, "privmsg")    
      end     

      if draws > 0 
         np = game.next_player
         skip(game, game.next_player)
         draw(game, np.nick, np.host, draws, "penalty")  
      end
      if skips > 0  
	     if game.players.size == 2
		    np = game.next_player
			skip(game, np)
		 else
            np = game.next_player
            1.upto(skips) { |n| 
               skip(game, np)
               np = game.next_player
            }
	     end		
      end   
      turn(game)
   end   
   def parse_cmd(hash, game) 
       case hash['msg']
          when "!join"
             join(game, hash['nick'], hash['host'])
          when "!cancel"
             cancel(game)
          when "!hand"
             hand(game, hash['nick'], hash['host'])  
          when "hand"
             hand(game, hash['nick'], hash['host'])            
          when "!pile"
             pile(game)
          when "pile"
             pile(game)             
          when "!deck"
             deck(game)
          when "deck"
             deck(game)
          when "!modify"
             rules(game, hash['host'])
          when "!count"
             count(game)  
          when "count" 
             count(game)  
          when "!begin"
             begin_uno(game, hash['host']) 
          when "!calluno"
             set_call_uno(game, hash['host'])  
          when "!uno"
             call_uno(game, hash['nick'], hash['host'])
          when "uno"
             call_uno(game, hash['nick'], hash['host'])
          when /^(!color|color)/
             select_color(game, hash['nick'], hash['host'], hash['msg'])          
          when "!draw"
             draw(game, hash['nick'], hash['host'], 1, "draw")
          when "d"
             draw(game, hash['nick'], hash['host'], 1, "draw")
          when "!pass"
             pass(game, hash['nick'], hash['host'])
          when "pass"
             pass(game, hash['nick'], hash['host'])
          when "!unostop"
             unostop(game, hash['nick'], hash['host'])
       end
   end    
   def parse_play(hash, game) 
      if game.state == "color" or game.state == "join"
         return
      end
 
      pcards = Deck.new
      player = game.find_player(hash['host'])
      if player.nil?
         return 
      end 
 
      msg = hash['msg']
	  
	  # detect correct syntax
	  s = StringScanner.new(msg)
      s.scan(/(\w+) (\w+)/)
	  
	  if !(s[2].nil?)
	     if s[2].length >= 1 and s[2].length <= 4
            if !(s[1] =~ /(\bplay|\bp)/ and ( s[2] =~ /^[rgbyw][0-9idsr]/i or s[2] =~ /^[w]/i ))
               return
            end
         else
            return   
         end
	  else 
	     return
	  end		 
	  
      msg = msg.sub(/\w+/, "")
      cards = msg.split(" ")  
      if cards.empty?
         return
      end 
      if game.rules == 0 and player != game.turn
         msg = "#{player.nick}! Wait your turn asshole!"
         uno_io(msg, game.channel, "privmsg")
         return 
      elsif game.rules > 0 and cards.length > 1 and player != game.turn
         msg = "#{player.nick}! You can only jump in with one card. For being a moron you must draw one card."
         uno_io(msg, game.channel, "privmsg")  
         draw(game, player.nick, player.host, 1, "penalty")
         return 
      end
      if cards.length > 1 and game.rules == 0
         msg = "#{player.nick}, you may only play one card at a time!"
         uno_io(msg, game.channel, "privmsg")
         return 
      end 
      for card in cards
         tmp = Card.new(nil, nil, nil, nil)
         case card
            when /^(r|b|g|y)/i then
               case card
                  when /^r/i then tmp.color = "red"
                  when /^b/i then tmp.color = "blue"
                  when /^g/i then tmp.color = "green"
                  when /^y/i then tmp.color = "yellow"
               else
                  return 
               end
            when /^w/i then
               case card
                  when /(wd4|wdf)/i
                     tmp.special = "WILD DRAW FOUR"
                  when /(w|wild)/i
                     tmp.special = "WILD"
                  else
                     return
               end
            else
               return
         end    
         if !(tmp.color.nil?) 
            case card
               when /[a-z][a-z]/i then
                 case card[1].chr
                    when /r/i then tmp.honor = "Reverse"
                    when /s/i then tmp.honor = "Skip"
                    when /d/i then tmp.honor = "Draw Two"
                    else return
                 end
               when /[a-z][0-9]/i then
                    tmp.number = card[1].chr
               else
                    return 
            end
         end
         ptmp = player.hand.find(tmp)   
         if ptmp.nil?
            msg = "#{player.nick}, you do not have a #{UNO.color_card(tmp)} ! For being a dumbass you must draw a card!"
            uno_io(msg, game.channel, "privmsg")
            draw(game, player.nick, player.host, 1, "penalty")
            return
         end 
         pcards.append(ptmp)    
      end   
      if pcards.size > 1 
         uniqpcards = pcards.cards.uniq
         uniqpcards.each { |c|
            
            unless player.hand.num_of(c) >= pcards.num_of(c)
               msg = "#{player.nick}, you do not have #{pcards.num_of(c)} #{UNO.color_card(c)}'s ! You must draw a card for being unable to count!"
               uno_io(msg, game.channel, "privmsg")
               draw(game, player.nick, player.host, 1, "penalty")
               return
            end
         }  
         if !(UNO.match_multi(game, pcards))
            msg = "#{player.nick}, you may only play multiple cards that match by number or ability. No Wilds! For being an idiot you must draw a card!"
            uno_io(msg, game.channel, "privmsg")
            draw(game, player.nick, player.host, 1, "penalty")
            return 
         end
      end   
      if game.rules > 0 and game.turn != player
         if !(game.pile.top.cmp(pcards[0])) or !(pcards[0].special.nil?)
            msg = "#{player.nick}, you may only cut-in with a card that matches both the color and type of the card in play! No Wilds!"
            uno_io(msg, game.channel, "privmsg")
            msg = "For being greedy, you must draw a card!"
            uno_io(msg, game.channel, "privmsg")
            draw(game, player.nick, player.host, 1, "penalty")
            return
         end
         msg = "#{player.nick}, has cut-in with a #{UNO.color_card(pcards[0])}!"
         uno_io(msg, game.channel, "privmsg")  
         game.turn.state = "none"
         game.turn = player
         play(game, player, pcards)
         return
      end
      if !(UNO.match(game, pcards[0]))
         msg = "A #{UNO.color_card(pcards[0])} does not match a #{UNO.color_card(game.pile.top)}"
         uno_io(msg, game.channel, "privmsg")
         msg = "For being an idiot you must draw a card!"
         uno_io(msg, game.channel, "privmsg")
         draw(game, player.nick, player.host, 1, "penalty")
         return 
      end  
      
      play(game, player, pcards)
      return 
   end      
   attr_reader :games, :cmds
   attr_writer :games, :cmds
end


