# frozen_string_literal: true

require 'sequel'
require 'pg'
require_relative 'postgres'

# system('createdb personal_finance')
# Keep global description of schema, diff new versions
# Only apply differences

DB = Sequel.connect(Postgres::SERVER_URL)

DB.create_table :people do
  primary_key :id
  String :name
end

DB.create_table :accounts do
  primary_key :id
  String :name
end

DB.create_table :transactions do
  primary_key :id
  foreign_key :account_id, :accounts
  Float :amount
  String :currency
  String :name
  Integer :day_of_month
end

DB.create_table :transaction_tags do
  primary_key :id
  foreign_key :transaction_id, :transactions
  String :name
end

# make transaction tags

# items = DB[:people]

# # Populate the table
# items.insert(:name => 'abc')
# items.insert(:name => 'def')
# items.insert(:name => 'ghi')
