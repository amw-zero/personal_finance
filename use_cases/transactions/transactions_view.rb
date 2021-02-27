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

  attr_reader :new_transaction_interaction, :data, :params, :accounts, :interactions

  def initialize(new_transaction_interaction:, accounts:, data:, params:, interactions:)
    @new_transaction_interaction = new_transaction_interaction
    @accounts = accounts
    @page = :transactions
    @data = data
    @params = params
    @interactions = interactions
  end

  def template
    File.read('use_cases/transactions/transactions_view.erb')
  end
end
