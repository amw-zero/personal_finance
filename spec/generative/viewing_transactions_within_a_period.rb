# frozen_string_literal: true

require_relative '../test_application'
require_relative './actions'

require 'hypothesis'

describe 'Viewing Transactions within a Period' do
  include Hypothesis
  include Hypothesis::Possibilities

  specify do
    # TODO: Meta-tests. If an account isn't created here, a transaction never will be,
    # and the test will always pass
    test_actions = [
      ApplicationActions::CREATE_ACCOUNT,
      ApplicationActions::CREATE_TRANSACTION,
    ]

    max_transaction_count = 0

    ApplicationActions::Sequences.new(
      test_actions,
      fresh_application: -> { test_application }
    ).check! do |test_app|
      transaction_count = test_app.all_transactions.transactions.count
      max_transaction_count = transaction_count if transaction_count > max_transaction_count

      next if test_app.all_transactions.transactions.empty?

      gen_date = ->(greater_than:) do
        built_as do
          greater_than + any(integers(min: 0, max: 2_000))
        end
      end
      start_date = any gen_date.call(greater_than: Date.new(1900, 1, 1)), name: 'Start Date'
      end_date = any gen_date.call(greater_than: start_date), name: 'End Date'

      period = start_date..end_date
      params = {
        within_period: period
      }

      # transaction = any element_of(test_app.transactions(params).transactions)

      # if period.begin != period.end
      #   expect(transaction.occurrences_within(period)).to_not be_empty
      # end
      
      # expect(transaction.occurrences_within(period).all? do |date|
      #   period.include?(date)
      # end)

      transactions = test_app.transactions({ within_period: period }).transactions
      transactions.all? do |transaction|
        rule = RRule::Rule.new(transaction.planned_transaction.recurrence_rule)
        expected_dates = rule.between(period.begin.to_datetime, period.end.to_datetime)
        associated_transactions = transactions.select { |t| t.planned_transaction.id == transaction.planned_transaction.id }

        associated_transactions.all? { |at| expected_dates.include?(at.date) }
      end
    end

    expect(max_transaction_count).to be > 0
  end
end