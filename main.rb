require 'rubygems'
require 'sinatra'

set :sessions, true

helpers do
  
  def player_new_card
    session[:player_cards] << session[:deck].pop
  end
  
  def dealer_new_card
    session[:dealer_cards] << session[:deck].pop
  end
    
  def player_update_score
    session[:player_score] = calculate_total(session[:player_cards])
  end

  def dealer_update_score
    session[:dealer_score] = calculate_total(session[:dealer_cards])
  end
  
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
    
    # Add aces to score. 
    # Also keep track of hard vs. soft hands. Soft hand means there's an ace worth 11.

    session[:soft_ace] = false # Unless there's still an ace worth 11.

    number_of_aces.times do
      if total + 11 > 21
        total += 1
      else
        total += 11
        session[:soft_ace] = true
      end
    end

    total
  end
  
  def did_player_win_or_bust
    player_score = player_update_score
    
    if player_score > 21
      @error = "Bust! Dealer wins since you have more than 21."
      dealer_wins
    elsif player_score == 21
      @success = "Blackjack! You won with 21 points."
      player_wins
    end
  end
  
  def who_won
    player_score = player_update_score  
    dealer_score = dealer_update_score
    
    if dealer_score > 21
      @success = "Dealer busted. You win!"
      player_wins
    elsif dealer_score == 21
      @error = "You lose! Dealer wins with 21 points."
      dealer_wins
    elsif dealer_score > 17
      compare_scores
    elsif dealer_score == 17
      if session[:soft_ace] == false # A hard 17 means dealer stays.
        compare_scores
      end
    else
    # Nobody won yet. Play continues.
    end
  end

  def compare_scores
    player_score = session[:player_score]
    dealer_score = session[:dealer_score]

    if player_score > dealer_score
      @success = "You win! You beat the dealer's score."
      player_wins
    elsif player_score < dealer_score
      @error = "You lose! Dealer wins by beating your score."
      dealer_wins      
    elsif player_score == dealer_score
      @success = "Tie game. Both players have the same score."
      tie_game
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
  # Clear the session variables.
  session[:player_name] = false
  session[:betting_person] = false
  session[:player_money] = 0
  session[:wager] = 0
  session[:soft_ace] = false
  
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
  dealer_new_card
  dealer_new_card  

  session[:player_cards] = []
  player_new_card
  player_new_card

  dealer_update_score
  player_update_score

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

  player_new_card
  
  did_player_win_or_bust
  
  erb :game, layout: false
end

post '/game/player/stay' do
  session[:turn] = 'dealer'
  who_won
  # Otherwise, witch from player's to dealer's turn.
  erb :game, layout: false
end

post '/game/dealer/next' do

  dealer_score = dealer_update_score
  
  if dealer_score < 17 # Dealer hits.
    dealer_new_card
  elsif dealr_score == 17 # Dealer hits only if it's a hand with a "soft" ace.
    if session[:soft_ace] 
      dealer_new_card
    end
  end
  
  # Check if the dealer's new hand ends the game.
  who_won
  # If nobody won yet, "Next" button is still visible and play continues.

  erb :game, layout: false
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