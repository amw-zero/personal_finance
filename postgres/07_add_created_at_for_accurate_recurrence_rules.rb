# frozen_string_literal: true

require 'sequel'
require_relative 'postgres'

DB = Sequel.connect(Postgres::SERVER_URL)

DB.alter_table(:transactions) do
  add_column :created_at, DateTime
end
