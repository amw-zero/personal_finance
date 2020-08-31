require 'sequel'
require 'pg'
require_relative 'postgres'

# system('createdb personal_finance')

DB = Sequel.connect(Postgres::SERVER_URL)

DB.create_table :people do
  primary_key :id
  String :name
end

items = DB[:people]

# Populate the table
items.insert(:name => 'abc')
items.insert(:name => 'def')
items.insert(:name => 'ghi')