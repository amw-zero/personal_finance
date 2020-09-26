# frozen_string_literal: true

require 'sinatra'
require 'ostruct'
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
  @is_tag_intersection = params[:intersection] == 'on'
  @tagged_transactions = if params[:transaction_tag]
                           application.transactions_for_tags(
                             params[:transaction_tag],
                             @tag_index,
                             intersection: params[:intersection] == 'on'
                           )
                         elsif params[:transaction_tag_set]
                           application.transactions_for_tag_sets(params[:transaction_tag_set])
                         else
                           nil
                         end

  @tag_sets = application.all_transaction_tag_sets

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
    name: params[:name],
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

post application.endpoints[:tag_sets_post][:path] do
  application.endpoints[:tag_sets_post][:action].call(params)

  redirect '/'
end
