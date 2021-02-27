# frozen_string_literal: true

require_relative '../../view'

class TransactionTableHeaderView
  include View

  attr_reader :title, :interactions

  def initialize(title:, interactions:)
    @title = title
    @interactions = interactions
  end

  def template
    File.read('use_cases/transactions/transaction_table_header_view.erb')
  end
end
