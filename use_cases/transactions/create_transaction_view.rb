# frozen_string_literal: true

require_relative '../../view'

class CreateTransactionView
  include View

  attr_reader :interactions

  def initialize(interactions:, accounts:)
    @interactions = interactions
    @accounts = accounts
  end

  def template
    File.read('use_cases/transactions/create_transaction_view.erb')
  end
end
