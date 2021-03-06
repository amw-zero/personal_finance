# frozen_string_literal: true

require_relative '../test_application'
require_relative './actions'
require_relative './propositions'
require 'hypothesis'

describe 'Creating, updating, and deleting Transactions' do
  include Hypothesis
  include Hypothesis::Possibilities

  specify 'Deleting Transactions' do
    test_actions = [
      ApplicationActions::CREATE_ACCOUNT,
      ApplicationActions::CREATE_SCENARIO,
      ApplicationActions::CREATE_TRANSACTION
    ]

    ApplicationActions::Sequences.new(
      test_actions,
      fresh_application: -> { test_application }
    ).check! do |test_app|
      starting_transactions = test_app.execute_and_render(test_app.interactions[:view_transactions]).data[:transactions].transactions
      next if starting_transactions.empty?

      transaction_to_delete = any element_of(starting_transactions)

      test_app.delete_transaction({ id: transaction_to_delete.id })

      all_transactions = test_app.execute_and_render(test_app.interactions[:view_transactions]).data[:transactions].transactions

      expect(Set.new(all_transactions)).to eq(Set.new(starting_transactions - [transaction_to_delete]))
    end
  end
end
