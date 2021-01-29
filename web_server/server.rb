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
                         end

  @tag_sets = application.all_transaction_tag_sets

  erb :home
end

application.endpoints.each do |_name, endpoint|
  case endpoint[:method]
  when :post
    post endpoint[:path] do
      endpoint[:action].call(params)

      redirect '/'
    end
  end
end
