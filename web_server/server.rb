# frozen_string_literal: true

require 'sinatra'
require 'ostruct'
require_relative '../personal_finance'
require_relative '../postgres/postgres_persistence'

application = PersonalFinance::Application.new(log_level: ENV['LOG_LEVEL'], persistence: PostgresPersistence.new)

get '/' do
  @people = application.people
  @accounts = application.accounts
  @cash_flow = if params[:account]
                 application.cash_flow(params[:account].to_i)
               else
                 application.all_transactions
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
                         end

  @tag_sets = application.all_transaction_tag_sets
  @page = :dashboard

  erb :home
end

get '/transactions/create' do
  @accounts = application.accounts
  erb :transaction_form
end

get '/transactions/:id/tags/create' do
  @transaction = application.all_transactions.find { |t| t.id == params[:id].to_i }
  erb :transaction_tag_form
end

application.use_cases.each do |_name, use_case|
  use_case.endpoints.each do |endpoint|
    case endpoint[:method]
    when :get
      get endpoint[:path] do
        data = endpoint[:action].call(params)

        @page = endpoint[:page] || use_case.name

        erb use_case.name, locals: {
          data: data,
          accounts: application.accounts,
          params: params
        }
      end
    when :post
      post endpoint[:path] do
        endpoint[:action].call(params)

        redirect endpoint[:return] || endpoint[:path]
      end
    end
  end
end
