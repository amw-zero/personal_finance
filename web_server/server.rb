require 'sinatra'
require_relative '../personal_finance'

get '/' do
  people = [
    PersonalFinance::Model.new.create_person('Person 1'),
    PersonalFinance::Model.new.create_person('Person 2'),
    PersonalFinance::Model.new.create_person('Person 3'),
    PersonalFinance::Model.new.create_person('Person 4'),
  ]
  erb :people, locals: { people: people }
end
