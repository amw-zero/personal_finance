# frozen_string_literal: true

require_relative '../../memory_persistence'
require_relative '../../data_interactor'
require_relative '../../types'

module UseCase
  class Transactions
    extend Forwardable
    def_delegators :@data_interactor, :to_models, :relation

    def initialize(persistence: MemoryPersistence.new)
      @persistence = persistence
      @data_interactor = DataInteractor.new(persistence)
    end

    # TODO: Test from_params methods separately
    # Can simply call the method to check for type check errors.
    def create_transaction_from_params(params)
      occurs_on = params[:occurs_on].empty? ? nil : Date.parse(params[:occurs_on])
      create_transaction(
        name: params[:name],
        account_id: params[:account_id].to_i,
        amount: params[:amount].to_f,
        currency: params[:currency].to_sym,
        recurrence_rule: params[:recurrence_rule],
        occurs_on: occurs_on,
        scenario_id: params[:scenario_id].to_i
      )
    end

    def create_transaction(name:, account_id:, amount:, currency:, recurrence_rule:, scenario_id:, occurs_on: Date.today)
      # This is to be able to start the recurrence rule in the past, so that
      # the transaction appears if you display months in the past
      occurs_on ||= Date.today
      one_thousand_weeks = (7 * 1_000)
      PlannedTransaction.new(
        name: name,
        account_id: account_id,
        amount: amount,
        currency: currency,
        recurrence_rule: recurrence_rule,
        scenario_id: scenario_id,
        occurs_on: (occurs_on - one_thousand_weeks)
      ).tap do |i|
        @persistence.persist(:transactions, persistable_transaction(i))
      end
    end

    # (params, is_schedule, relation(:transactions))
    def transactions(params, is_schedule: false)
      params = params.merge({ date_period: 'current_month' }) if params[:date_period].nil? && is_schedule
      period = if params[:start_date] && !params[:start_date].empty? && params[:end_date] && !params[:end_date].empty?
                 Date.parse(params[:start_date])..Date.parse(params[:end_date])
               elsif params[:date_period] == 'current_year'
                 today = Date.today
                 new_years = Date.new(today.year, 1, 1)
                 new_years_eve = Date.new(today.year, 12, 31)

                 new_years..new_years_eve
               elsif params[:date_period] == 'current_month'
                 today = Date.today
                 first = Date.new(today.year, today.month, 1)
                 last = Date.new(today.year, today.month + 1, 1) - 1

                 first..last
               end

      rel =
        if params[:transaction_tag]
          transactions_for_tags(
            params[:transaction_tag],
            tag_index,
            intersection: params[:intersection] == 'true'
          )
        elsif params[:transaction_tag_set]
          params[:transaction_tag_set].empty? ? [] : transactions_for_tag_sets(params[:transaction_tag_set])
        elsif params[:account]
          cash_flow(params[:account].to_i)
        else
          relation(:transactions)
        end

      rel = rel.restrict(scenario_id: params[:scenario_id])
      applicable_transactions = to_models(rel, PlannedTransaction).sort_by(&:name)

      # This branch has to come out of here. Different types get returned from this function
      if period
        applicable_transactions = applicable_transactions.flat_map do |transaction|
          transaction.occurrences_within(period).map do |date|
            Transaction.new(date: date.to_date, planned_transaction: transaction)
          end
        end.sort_by(&:date)

        periods = if applicable_transactions.any?(&:income?)
                    partition_transactions_by_pay_period(applicable_transactions, in_period: period)
                  else
                    partition_transactions_by_month(applicable_transactions, in_period: period)
                  end
        return {
          tag_index: tag_index,
          transactions: periods
        }
      end

      # Move non-transaction data up into Application
      {
        tag_index: tag_index,
        tag_sets: all_transaction_tag_sets,
        transactions: TransactionSet.new(transactions: applicable_transactions)
      }
    end

    def cash_flow(account_id)
      transactions = relation(:transactions)
      accounts = relation(:accounts).restrict(id: account_id)

      transactions.join(accounts, { account_id: :id })
    end

    def all_transaction_tag_sets
      to_models(relation(:transaction_tag_sets), TransactionTagSet)
    end

    def delete_transaction(params)
      @persistence.delete(
        :transactions,
        relation(:transactions).restrict(id: params[:id].to_i)
      )
    end

    def tag_index
      to_models(
        relation(:transaction_tags),
        TransactionTag
      ).group_by(&:transaction_id)
    end

    def persist_transaction(t)
      @persistence.persist(:transactions, persistable_transaction(t))
    end

    private

    def partition_transactions_by_month(transactions, in_period:)
      raise if in_period.begin.year != in_period.end.year

      months = in_period.begin.month.upto(in_period.end.month + 1).with_index.map do |month, _i|
        year_offset = month / 12

        Date.new(in_period.begin.year + year_offset, (month % 12).zero? ? 12 : month % 12, 1)
      end
      periods = months.each_cons(2).map { |dates| Range.new(*dates, true) }
      periods[-1] = periods[-1].begin..periods[-1].end

      periods.map do |period|
        Period.new(
          transactions: TransactionSet.new(transactions: transactions.select { |t| period.include?(t.date) }),
          date_range: period
        )
      end
    end

    def partition_transactions_by_pay_period(transactions, in_period:)
      income_dates = Set.new(transactions.select(&:income?).map(&:date))
      all_dates = Set.new([in_period.begin] + income_dates.to_a.sort.drop(1) + [in_period.end + 1])
      income_periods = all_dates.to_a.each_cons(2).map { |dates| Range.new(dates[0].to_date, dates[1].to_date, true) }

      income_periods.map do |period|
        PayPeriod.new(
          incomes: TransactionSet.new(transactions: transactions.select do |t|
                                                      t.income? && period.include?(t.date.to_date)
                                                    end),
          transactions: TransactionSet.new(transactions: transactions.select do |t|
                                                           !t.income? && period.include?(t.date.to_date)
                                                         end),
          date_range: period
        )
      end
    end

    def transactions_for_tags(tags, tag_index, intersection: false)
      if intersection
        transaction_ids = tag_index.select do |_, t|
          (t.map(&:name) & tags).count == tags.count
        end.keys
        relation(:transactions).restrict(id: transaction_ids)
      else
        _transactions_for_tags(tags)
      end
    end

    def transactions_for_tag_sets(tag_set_ids)
      tag_sets = to_models(
        relation(:transaction_tag_sets).restrict(id: tag_set_ids),
        TransactionTagSet
      )

      return [] if tag_sets.empty?

      _transactions_for_tags(tag_sets.first.tags)
    end

    def persistable_transaction(transaction)
      # TODO: the attributes are mutable here, and this is surprising and confusing
      # Persisting this later one modifies the attributes which modifies the struct.
      # Terrifying.
      transaction.attributes.merge!(
        {
          currency: transaction.currency.to_s
        }
      )
    end

    def _transactions_for_tags(tags)
      transaction_ids = relation(:transaction_tags)
                        .restrict(name: tags)
                        .map { |tag| tag[:transaction_id] }

      relation(:transactions).restrict(id: transaction_ids)
    end
  end
end
