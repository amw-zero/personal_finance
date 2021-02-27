# frozen_string_literal: true

require_relative '../../view'

class PlannedTransactionTableView
  include View
  attr_reader :transactions, :tag_index

  def initialize(transactions:, tag_index:)
    @transactions = transactions
    @tag_index = tag_index
  end

  def get_binding
    binding
  end

  def template
    File.read('use_cases/transactions/planned_transaction_table_view.erb')
  end
end
