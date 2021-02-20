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
      start_date = any gen_date.call(greater_than: Date.new(2021, 1, 1)), name: 'Start Date'
      end_date = any gen_date.call(greater_than: start_date), name: 'End Date'

      period = start_date..end_date
      params = {
        within_period: period
      }

      pay_periods = test_app.transactions({ within_period: period })

      # Expected occurrences are what the rrule expansion says they should be
      expected_occurrences = test_app.all_transactions.transactions.map do |transaction|
        [
          transaction.id,
          RRule
            .parse(transaction.recurrence_rule, dtstart: period.begin.to_time, tzid: Time.now.getlocal.zone)
            .between(period.begin.to_time, period.end.to_time)
            .map { |date_time| date_time.to_date.to_s }
        ]
      end.to_h

      # All transactions get expanded into their proper occurrences
      pay_periods
        .flat_map do |period|
          if period.is_a?(Period)
            period.transactions.transactions
          else
            period.transactions.transactions + period.incomes.transactions
          end
        end
        .group_by { |transaction| transaction.planned_transaction.id }
        .transform_values { |transactions| transactions.map { |t| t.date.to_s } }
        .each do |transaction_id, occurrences|
          expect(occurrences).to eq(expected_occurrences[transaction_id])
        end

      # Transactions are grouped by pay period
      # income_dates = d
      # incomes = test_app.all_transactions.transactions.select { |t| t.income? }

      # if incomes.count > 0 && pay_periods.any? { |p| p.is_a?(Period) }
      #   require 'pry'
      #   binding.pry
      # end
      # incomes.each do |income|
      #   pay_periods.count { |period| period.incomes.transactions.include?(income) } == 1
      # end
    end

    expect(max_transaction_count).to be > 0
  end
end
