require 'sinatra'
require_relative '../personal_finance'

model = PersonalFinance::Model.new

all_people = [
  model.create_person('Person 1'),
  model.create_person('Person 2'),
  model.create_person('Person 3'),
  model.create_person('Person 4'),
]

get '/' do
  @people = all_people
  erb :home
end

post '/people' do
  all_people << model.create_person(params[:name])
  @people = all_people
  erb :home
end
