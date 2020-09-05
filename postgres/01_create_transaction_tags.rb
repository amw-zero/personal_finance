require 'sequel'
require_relative 'postgres'

DB = Sequel.connect(Postgres::SERVER_URL)

DB.create_table :transaction_tags do
  primary_key :id
  foreign_key :transaction_id, :transactions
  String :name
end