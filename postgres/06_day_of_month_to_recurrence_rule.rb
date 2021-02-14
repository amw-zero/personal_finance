require 'sequel'
require_relative 'postgres'

DB = Sequel.connect(Postgres::SERVER_URL)

DB.alter_table(:transactions) do
  drop_column :day_of_month
  add_column :recurrence_rule, String
end