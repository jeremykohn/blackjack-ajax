require 'rubygems'
require 'sinatra'

set :sessions, true

helpers do
  
  def calculate_total(cards)
    values = cards.map{|element| element[1]}
    total = 0
    number_of_aces = 0

    # Add non-ace cards to score.
    values.each do |card_value|
      if card_value == "ace"
        number_of_aces += 1 # Keep track of aces for later.
      elsif card_value.to_i == 0 # Either a jack, queen, or king
        total += 10
      else
        total += card_value.to_i
      end
    end
    
    session[:soft_hand] = false
    # Change to "true" if there's an ace worth 11.  
    # A "soft" hand is one that includes an ace worth 11.
    # Dealer stays if a hard 17, hits if a soft 17.   
    
    # Add aces to score. Keep track of hard vs. soft hands.
    number_of_aces.times do
      if total + 11 > 21
        total += 1
      else
        total += 11
        session[:soft_hand] = true
      end
    end    

    total
  end
  
  def who_won(dealer_score, player_score)
    if dealer_score > 21 # Dealer busts.
      @success = "Dealer busted. You win!"
      player_wins
    elsif dealer_score == 21 # Blackjack for dealer.
      @error = "You lose! Dealer wins with 21 points."
      dealer_wins
    elsif dealer_score >= 17
      # Compare scores.
      if player_score > dealer_score
        @success = "You win! You beat the dealer's score."
        player_wins
      elsif player_score == dealer_score
        @success = "Tie game. Both players have the same score."
        tie_game
      else
        @error = "You lose! Dealer wins by beating your score."
        dealer_wins
      end
    end
  end

  def display_card(card)
    suit = card[0]
    value = card[1]
    "<img src='/images/cards/" + suit + "_" + value + ".jpg' class='card_image'>"
  end
  
  def player_wins
    session[:winner] = 'player'
    session[:player_money] += session[:wager]
    session[:turn] = 'end'
  end

  def dealer_wins
    session[:winner] = 'dealer'
    session[:player_money] -= session[:wager]
    session[:turn] = 'end'
  end
  
  def tie_game
    session[:winner] = 'tie'
    # Player neither wins nor loses money.
    session[:turn] = 'end'
  end

end


# Now, the routes.

get '/' do
  redirect '/new_player'
end

get '/new_player' do
  # Clear the player's name & betting-person status
  session[:player_name] = false
  session[:betting_person] = false
  erb :new_player
end

post '/new_player' do
  session[:player_name] = params[:player_name]
  if session[:player_name] == ''
    session[:no_name] = true
    redirect '/new_player'
  else
    session[:no_name] = false
    redirect '/bet'
  end
end

get '/bet' do
  # This screen asks whether player is a betting person.
  erb :bet
end

get '/bet/yes' do
  session[:betting_person] = true
  session[:player_money] = 500 # Starting value.
  redirect '/bet_amount'
  erb :bet
end

get '/bet/no' do
  session[:betting_person] = false
  redirect '/game'
  erb :bet
end

get '/bet_amount' do
  if session[:player_money] == 0
    redirect '/out_of_money'
  end
  erb :bet_amount
end

post '/bet_amount' do
  wager_amount = params[:wager].to_i
  if wager_amount <= 0 
    @bet_error = "Please enter a positive number."
  elsif wager_amount > session[:player_money] 
    @bet_error = "You cannot wager more money than you have."
  else
    session[:wager] = wager_amount
    redirect '/game'
  end
  erb :bet_amount
end

get '/out_of_money' do
  erb :out_of_money
end

get '/game' do
  
  if session[:player_name] == false
    redirect '/new_player'
  end

  # Create deck.
  suits = ['hearts', 'diamonds', 'clubs', 'spades']
  values = ['2', '3', '4', '5', '6', '7', '8', '9', '10', 'jack', 'queen', 'king', 'ace']
  session[:deck] = suits.product(values).shuffle!

  # Deal cards.
  session[:dealer_cards] = []
  session[:player_cards] = []
  session[:dealer_cards] << session[:deck].pop
  session[:player_cards] << session[:deck].pop
  session[:dealer_cards] << session[:deck].pop
  session[:player_cards] << session[:deck].pop
  
  # Player's turn begins.
  session[:turn] = 'player'
  
  # Check if player has blackjack.
  if calculate_total(session[:player_cards]) == 21
    @success = "Blackjack! You won with 21 points."
    player_wins
  end

  erb :game
end

post '/game/player/hit' do
  session[:player_cards] << session[:deck].pop
  
  player_score = calculate_total(session[:player_cards])

  # See if player either has blackjack now or busted.
  if player_score > 21
    @error = "Bust! Dealer wins since you have more than 21."
    dealer_wins
  elsif player_score == 21
    @success = "Blackjack! You won with 21 points."
    player_wins
  end
  # Otherwise, player has less than 21 and can either hit again or stay.
  
  erb :game
end

post '/game/player/stay' do
  # Switch from player's to dealer's turn.
  session[:turn] = 'dealer'
  erb :game
end

post '/game/dealer/next' do
  # Current scores.
  player_score = calculate_total(session[:player_cards])  
  dealer_score = calculate_total(session[:dealer_cards])

  # Dealer will hit or stay based on current score.

  if dealer_score < 17 # Dealer hits.
    session[:dealer_cards] << session[:deck].pop
  elsif dealer_score == 17 # Dealer hits only if it's a "soft" hand.
    if sessions[:soft_hand]
      session[:dealer_cards] << session[:deck].pop
    end
  else # Dealer stays. End of game. Compare scores.
    who_won(dealer_score, player_score)
  end

  erb :game
end

get '/game/play_again_yes' do
  if session[:betting_person] == true
    redirect '/bet_amount'
  else
    redirect '/game'
  end
  erb :game
end

get '/game/play_again_no' do
  redirect '/thanks_for_playing'
  erb :game
end

get '/thanks_for_playing' do
  erb :thanks_for_playing
end