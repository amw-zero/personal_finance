# frozen_string_literal: true

require_relative './transaction_filters_tags_view'
require_relative './transaction_filters_tag_sets_view'
require_relative './planned_transaction_table_view'
require_relative './transaction_table_header_view'
require_relative './transactions_by_month_view'
require_relative './transactions_by_pay_period_view'

require_relative '../../view'

class TransactionsView
  include View

  attr_reader :new_transaction_interaction, :data, :params, :page, :accounts, :interactions, :scenarios, :selected_scenario_id

  def initialize(new_transaction_interaction:, accounts:, data:, page:, params:, interactions:, scenarios:)
    @new_transaction_interaction = new_transaction_interaction
    @accounts = accounts
    @page = page
    @data = data
    @params = params
    @interactions = interactions
    @scenarios = scenarios
    @selected_scenario_id = params[:scenario_id].to_i
  end

  def template
    File.read('use_cases/transactions/transactions_view.erb')
  end
end
