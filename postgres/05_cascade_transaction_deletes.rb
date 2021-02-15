# frozen_string_literal: true

require 'sequel'
require_relative 'postgres'

DB = Sequel.connect(Postgres::SERVER_URL)

DB.alter_table(:transactions) do
  drop_foreign_key :account_id
  add_foreign_key :account_id, :accounts, on_delete: :cascade
end

DB.alter_table(:transaction_tags) do
  drop_foreign_key :transaction_id
  add_foreign_key :transaction_id, :transactions, on_delete: :cascade
end
