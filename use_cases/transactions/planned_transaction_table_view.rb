# frozen_string_literal: true

require_relative '../../view'

class PlannedTransactionTableView
  include View
  attr_reader :interactions, :transactions, :tag_index

  def initialize(interactions:, transactions:, tag_index:)
    @interactions = interactions
    @transactions = transactions
    @tag_index = tag_index
  end

  def template
    File.read('use_cases/transactions/planned_transaction_table_view.erb')
  end
end
