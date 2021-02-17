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

    # It should return all transactions which occur in the given period
    test_actions = [
      ApplicationActions::CREATE_ACCOUNT,
      ApplicationActions::CREATE_TRANSACTION
    ]

    max_transaction_count = 0

    ApplicationActions::Sequences.new(
      test_actions,
      fresh_application: -> { test_application }
    ).check! do |test_app|
      transaction_count = test_app.all_transactions.transactions.count
      max_transaction_count = transaction_count if transaction_count > max_transaction_count

      next if test_app.all_transactions.transactions.empty?

      gen_date = lambda do |greater_than:|
        built_as do
          greater_than + any(integers(min: 0, max: 50))
        end
      end
      start_date = any gen_date.call(greater_than: Time.new(2021, 1, 1).utc), name: 'Start Date'
      end_date = any gen_date.call(greater_than: start_date), name: 'End Date'

      period = start_date..end_date
      params = {
        within_period: period
      }

      transactions = test_app.transactions({ within_period: period }).transactions

      expected_occurrences = test_app.all_transactions.transactions.map do |transaction|
        [
          transaction.id,
          RRule
            .parse(transaction.recurrence_rule, dtstart: period.begin.to_datetime)
            .between(period.begin.to_datetime, period.end.to_datetime)
            .map { |date_time| date_time.to_date.to_s }
        ]
      end.to_h

      transactions
        .group_by { |transaction| transaction.planned_transaction.id }
        .transform_values { |transactions| transactions.map(&:date) }
        .each do |transaction_id, occurrences|
          expect(occurrences).to eq(expected_occurrences[transaction_id])
        end
    end

    expect(max_transaction_count).to be > 0
  end
end
