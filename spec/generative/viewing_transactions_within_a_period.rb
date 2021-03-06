# frozen_string_literal: true

require_relative '../test_application'
require_relative './actions'

require 'hypothesis'

describe 'Viewing Transactions within a Period' do
  include Hypothesis
  include Hypothesis::Possibilities

  specify do
    # Model after todo-subsecond.
    # Create "Assemblies" where I can test everything in memory,
    # or end to end depending on assembly. Same test.
    test_actions = [
      ApplicationActions::CREATE_ACCOUNT,
      ApplicationActions::CREATE_TRANSACTION
    ]

    max_transaction_count = 0

    ApplicationActions::Sequences.new(
      test_actions,
      fresh_application: -> { test_application }
    ).check!(max_checks: 200) do |test_app, _executed|
      all_transactions = test_app.all_transactions[:transactions].transactions
      transaction_count = all_transactions.count
      max_transaction_count = transaction_count if transaction_count > max_transaction_count

      next if all_transactions.empty?

      gen_date = lambda do |greater_than:|
        built_as do
          greater_than + any(integers(min: 0, max: 50))
        end
      end
      start_date = any gen_date.call(greater_than: Date.new(2021, 1, 1)), name: 'Start Date'
      end_date = any gen_date.call(greater_than: start_date), name: 'End Date'

      params = any(element_of([
                                {
                                  start_date: start_date.to_s,
                                  end_date: end_date.to_s
                                },
                                {
                                  date_period: 'current_month'
                                },
                                {
                                  date_period: 'current_year'
                                },
                                {}
                              ]), name: 'Params')

      period = if params[:start_date] && params[:end_date]
                 start_date..end_date
               elsif params[:date_period] == 'current_month' || params.empty?
                 today = Date.today
                 first = Date.new(today.year, today.month, 1)
                 last = Date.new(today.year, today.month + 1, 1) - 1

                 first..last
               else
                 params[:date_period] == 'current_year'
                 today = Date.today
                 new_years = Date.new(today.year, 1, 1)
                 new_years_eve = Date.new(today.year, 12, 31)

                 new_years..new_years_eve
               end

      view = test_app.execute(test_app.interactions[:view_transactions_schedule], params)

      expect(ErbRenderer.new(view).render).to_not be_nil

      pay_periods = test_app.transactions(params, is_schedule: true)[:transactions]

      # Expected occurrences are what the rrule expansion says they should be
      expected_occurrences = all_transactions.map do |transaction|
        [
          transaction.id,
          RRule
            .parse(transaction.recurrence_rule, dtstart: period.begin.to_time, tzid: Time.now.getlocal.zone)
            .between(period.begin.to_time, period.end.to_time)
            .map { |date_time| date_time.to_date.to_s }
        ]
      end.to_h

      # All transactions get expanded into their proper occurrences
      require 'pry'
      pay_periods
        .flat_map do |period|
          if period.is_a?(Period)
            period.transactions.transactions
          else
            period.transactions.transactions + period.incomes.transactions
          end
        end
        .group_by { |transaction| transaction.planned_transaction.id }
        .transform_values { |transactions| transactions.map(&:date) }
        .each do |transaction_id, occurrences|
          binding.pry if occurrences.any? { |o| !period.include?(o) }
          binding.pry if occurrences.map(&:to_s) != expected_occurrences[transaction_id]
          expect(occurrences.all? { |o| period.include?(o) }).to eq(true)
          expect(occurrences.map(&:to_s)).to eq(expected_occurrences[transaction_id])
        end

      # Transactions are grouped by pay period
      # income_dates = d
      # incomes = all_transactions.select { |t| t.income? }

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
