require 'sinatra'
require_relative '../personal_finance'

application = PersonalFinance::Application.new

# all_people = [
#   application.create_person('Person 1'),
#   application.create_person('Person 2'),
#   application.create_person('Person 3'),
#   application.create_person('Person 4'),
# ]

all_accounts = []

linked_accounts = []

get '/' do
  @people = application.all_people
  @accounts = all_accounts

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
 