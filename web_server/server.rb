require 'sinatra'
require_relative '../personal_finance'

application = PersonalFinance::Application.new

get '/' do
  @people = application.people
  @accounts = application.accounts
  @cash_flow = if params[:account]
                 application.cash_flow(params[:account].to_i)
               else
                 application.transactions
               end
  @tag_index = application.tag_index
  @filtered_tag = params[:transaction_tag]
  @tagged_transactions = if params[:transaction_tag]
                           application.transactions_for_tag(params[:transaction_tag])
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
  # add to application kernel, should only be:
  # application.create_transaction(params)
  # Can keep the same API internally with the above as an "anti-corruption" wrapper
  # which handles web concerns
  application.create_transaction(
    account_id: params[:account_id].to_i,
    amount: params[:amount].to_f,
    currency: params[:currency].to_sym,
    day_of_month: params[:day_of_month].to_i
  )

  redirect '/'
end

post '/transaction_tags' do
  application.tag_transaction(params[:transaction_id].to_i, tag: params[:name])

  redirect '/'
end
 