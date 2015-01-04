require 'rubygems'
require 'sinatra'
require 'sinatra/reloader' if development?

# set :sessions, true
# fix for Chrome
use Rack::Session::Cookie, :key => 'rack.session',
                           :path => '/',
                           :secret => 'random_string'

BLACKJACK = 21
DEALER_MIN_HIT = 17
PLAYER_MONEY_INIT = 500

helpers do
  def calculate_total(cards)
    arr = cards.map{|e| e[1] }

    total = 0
    arr.each do |value|
      if value == "ace"
        total += 11
      elsif value.to_i == 0
        total += 10
      else
        total += value.to_i
      end
    end

    arr.select{|element| element == "ace"}.count.times do
      total -= 10 if total > 21
    end

    total
  end

  def image_source(card)
    "<img src='/images/cards/" + card[0] + "_" + card[1] + ".jpg' class='card_image' />"
  end

  def show_hide
    @show_hit_stay_buttons = false
    @play_again = true
  end

  def winner!(msg)
    session[:player_money] = session[:player_money] + session[:bet_amount]
    @winner = "<strong>Congratulations, #{session[:player_name]}. You have won!</strong> #{msg} Now you have <strong>$#{session[:player_money]}</strong>."
  end

  def loser!(msg)
    session[:player_money] = session[:player_money] - session[:bet_amount]
    @loser = "<strong>Sorry, #{session[:player_name]}. You have lost.</strong> #{msg} Now you have <strong>$#{session[:player_money]}</strong>."
  end

  def tie!(msg)
    @winner = "<strong>It's a tie!</strong> #{msg}"
  end
end

before do
  @show_hit_stay_buttons = true
  @dealer_hidden_card = true
  @play_again = false
end

get '/' do
  if session[:player_name]
    redirect '/game'
  else
    redirect '/new_player'
  end
end

get '/new_player' do
  session[:player_money] = PLAYER_MONEY_INIT
  erb :new_player
end

post '/new_player' do
  if params[:player_name].empty?
    @error = "You must enter your name."
    halt erb(:new_player)
  elsif params[:player_name] =~ /[^a-zA-Z ]/
    @error = "Your name may contain only alphabetic characters."
    halt erb(:new_player)
  end
  session[:player_name] = params[:player_name].split.map(&:capitalize).join(" ")
  redirect '/place_bet'
end

get '/place_bet' do
  session[:bet_amount] = nil
  erb :place_bet  
end

post '/place_bet' do
  if params[:bet_amount].empty?
    @error = "You must enter the bet amount."
    halt erb(:place_bet)
  elsif params[:bet_amount].to_i <= 0
    @error = "You cannot bet a negative amount."
    halt erb(:place_bet)
  elsif params[:bet_amount].to_i > session[:player_money]
    @error = "You cannot bet more than $#{session[:player_money]}."
    halt erb(:place_bet)
  end
  session[:bet_amount] = params[:bet_amount].to_i
  redirect '/game'
end

get '/game' do
  suits = ['hearts', 'diamonds', 'spades', 'clubs']
  values = ['2', '3', '4', '5', '6', '7', '8', '9', '10', 'jack', 'queen', 'king', 'ace']

  session[:deck] = suits.product(values).shuffle!

  session[:dealer_cards] = []
  session[:player_cards] = []
  
  session[:dealer_cards] << session[:deck].pop
  session[:player_cards] << session[:deck].pop
  session[:dealer_cards] << session[:deck].pop
  session[:player_cards] << session[:deck].pop

  erb :game
end

post '/game/player/hit' do
  session[:player_cards] << session[:deck].pop
  player_total = calculate_total(session[:player_cards])
  if player_total == BLACKJACK
    show_hide
    winner!("You hit blackjack.")
  elsif player_total > BLACKJACK
    show_hide
    loser!("You busted at #{player_total}.")
   end
  erb :game, layout: false
end

post '/game/player/stay' do
  @success = "You have chosen to stay."
  @show_hit_stay_buttons = false
  @dealer_hidden_card = false

  redirect '/game/dealer'
end

get '/game/dealer' do
  @dealer_hidden_card = false
  dealer_total = calculate_total(session[:dealer_cards])
  if dealer_total == BLACKJACK
    show_hide
    loser!("The dealer hit blackjack.")
  elsif dealer_total > BLACKJACK
    show_hide
    winner!("The dealer busted at #{dealer_total}.")
  elsif dealer_total >= DEALER_MIN_HIT
    #dealer stays
    redirect '/game/compare'
  else
    #dealer hits
    @dealer_hit_btn = true
  end

  erb :game
end

post '/game/dealer/hit' do
  session[:dealer_cards] << session[:deck].pop
  redirect '/game/dealer'
end

get '/game/compare' do
  @show_hit_stay_buttons = false
  @dealer_hidden_card = false
  dealer_total = calculate_total(session[:dealer_cards])
  player_total = calculate_total(session[:player_cards])
  if dealer_total > player_total
    show_hide
    loser!("You stayed at #{player_total}, and the dealer stayed at #{dealer_total}.")
  elsif dealer_total < player_total
    show_hide
    winner!("You stayed at #{player_total}, and the dealer stayed at #{dealer_total}.")
  else
    show_hide
    tie!("You and the dealer both stayed at #{dealer_total}.")
  end

  erb :game, layout: false
end

get '/game_over' do
  erb :game_over
end

get '/no_money' do
  erb :no_money
end