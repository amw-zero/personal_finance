require 'sequel'
require_relative 'postgres'

DB = Sequel.connect(Postgres::SERVER_URL)

DB.create_table :transaction_tag_sets do
  primary_key :id
  String :tags
end