require 'sequel'
require_relative '../postgres'

Sequel.migration do
  change do
    create_table(:scenarios) do
      primary_key :id
      String :name
    end
    
    alter_table(:transactions) do
      add_column :scenario_id, :integer
    end
  end
end

