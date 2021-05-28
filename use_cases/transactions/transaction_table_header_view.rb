# frozen_string_literal: true

require_relative '../../view'

class TransactionTableHeaderView
  include View

  attr_reader :title, :interactions, :scenarios, :selected_scenario_id

  def initialize(title:, interactions:, scenarios:, selected_scenario_id:)
    @title = title
    @interactions = interactions
    @scenarios = scenarios
    @selected_scenario_id = selected_scenario_id
  end

  def template
    File.read('use_cases/transactions/transaction_table_header_view.erb')
  end
end
