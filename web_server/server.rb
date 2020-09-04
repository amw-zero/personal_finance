require 'sinatra'
require_relative '../personal_finance'

application = PersonalFinance::Application.new

get '/' do
  @people = application.people
  @accounts = application.accounts
  @cash_flow = if params[:account]
                 application.cash_flow(params[:account].to_i)
               else
                 []
               end

  erb :home
end

post '/people' do
  application.create_person(params[:name])

  redirect '/'
end

post '/accounts' do
  application.create_account(params[:name])

  redirect '/'
end

post '/transactions' do
  # TODO: These type coercions can be a source of bugs
  # add to application kernel
  application.create_transaction(
    account_id: params[:account_id].to_i,
    amount: params[:amount].to_f,
    currency: params[:currency].to_sym,
    day_of_month: params[:day_of_month].to_i
  )

  redirect '/'
end
 