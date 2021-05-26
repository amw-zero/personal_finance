# frozen_string_literal: true

require_relative '../../view'

class CreateTransactionView
  include View

  attr_reader :interactions

  def initialize(interactions:, accounts:, scenarios:)
    @interactions = interactions
    @accounts = accounts
    @scenarios = scenarios
  end

  def template
    File.read('use_cases/transactions/create_transaction_view.erb')
  end
end
