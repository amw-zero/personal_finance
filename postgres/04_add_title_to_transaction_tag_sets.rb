# frozen_string_literal: true

require 'sequel'
require_relative 'postgres'

DB = Sequel.connect(Postgres::SERVER_URL)

DB.alter_table(:transaction_tag_sets) do
  add_column :title, String
end
