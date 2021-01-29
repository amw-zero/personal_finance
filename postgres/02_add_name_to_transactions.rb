# frozen_string_literal: true

require 'sequel'
require_relative 'postgres'

DB = Sequel.connect(Postgres::SERVER_URL)

DB.add_column :transactions, :name, String
