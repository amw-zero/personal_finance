require 'sinatra'
require_relative '../personal_finance'

application = PersonalFinance::Application.new

get '/' do
  @people = application.people
  @accounts = application.accounts

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

post 'linked_accounts' do
end
 