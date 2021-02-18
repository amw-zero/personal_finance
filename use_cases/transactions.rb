# frozen_string_literal: true

require_relative '../memory_persistence'
require_relative '../data_interactor'
require_relative '../types'

module UseCase
  class Transactions
    extend Forwardable
    def_delegators :@data_interactor, :to_models, :relation

    def initialize(persistence: MemoryPersistence.new)
      @persistence = persistence
      @data_interactor = DataInteractor.new(persistence)
    end

    def name
      :transactions
    end

    def endpoints
      [
        {
          method: :post,
          path: '/transactions',
          action: lambda do |params|
            create_transaction_from_params(params)
          end
        },
        {
          method: :get,
          # Coupling here - /transactions is referred to in view
          # It should reference the use case path probably
          # Try and change this route and see what breaks
          path: '/transactions',
          action: lambda do |params|
            {
              tag_index: tag_index,
              transactions: transactions(params)
            }
          end
        },
        {
          method: :get,
          page: :transactions_tag_sets,
          path: '/transactions/tag_sets',
          action: lambda do |params|
            {
              tag_index: tag_index,
              tag_sets: all_transaction_tag_sets,
              transactions: transactions(params)
            }
          end
        },
        {
          method: :get,
          page: :transactions_schedule,
          path: '/transactions/schedule',
          action: lambda do |params|
            today = Date.today + 30
            first_of_month = Time.new(today.year, today.month, 1)
            end_of_month = Time.new(today.year, 12, 1) - 1

            {
              tag_index: tag_index,
              tag_sets: all_transaction_tag_sets,
              transactions: transactions(params.merge({
                                                        within_period: first_of_month..end_of_month
                                                      }))
            }
          end
        },
        # TODO: Simulate HTTP in tests and test proper endpoints / paths / actions
        {
          method: :delete,
          return: '/transactions',
          path: '/transactions/:id',
          action: lambda do |params|
            delete_transaction(params[:id])
          end
        }
      ]
    end

    # TODO: Test from_params methods separately
    # Can simply call the method to check for type check errors.
    def create_transaction_from_params(params)
      create_transaction(
        name: params[:name],
        account_id: params[:account_id].to_i,
        amount: params[:amount].to_f,
        currency: params[:currency].to_sym,
        recurrence_rule: params[:recurrence_rule]
      )
    end

    def create_transaction(name:, account_id:, amount:, currency:, recurrence_rule:)
      # This is to be able to start the recurrence rule in the past, so that
      # the transaction appears if you display months in the past
      one_thousand_weeks = (7 * 24 * 60 * 60 * 1000)
      PlannedTransaction.new(
        name: name,
        account_id: account_id,
        amount: amount,
        currency: currency,
        recurrence_rule: recurrence_rule,
        created_at: Time.now.utc - one_thousand_weeks
      ).tap do |i|
        @persistence.persist(:transactions, persistable_transaction(i))
      end
    end

    def transactions(params)
      applicable_transactions =
        if params[:transaction_tag]
          transactions_for_tags(
            params[:transaction_tag],
            tag_index,
            intersection: params[:intersection] == 'true'
          )
        elsif params[:transaction_tag_set]
          return TransactionSet.new(transactions: []) if params[:transaction_tag_set].empty?

          transactions_for_tag_sets(params[:transaction_tag_set])
        elsif params[:account]
          cash_flow(params[:account].to_i)
        else
          transactions = to_models(
            relation(:transactions),
            PlannedTransaction
          ).sort_by(&:name)
        end

      if params[:within_period]
        applicable_transactions = applicable_transactions.flat_map do |transaction|
          transaction.occurrences_within(params[:within_period]).map do |date|
            Transaction.new(date: date.to_date.to_s, planned_transaction: transaction)
          end
        end.sort_by(&:date) 

        return partition_transactions_by_pay_period(applicable_transactions, in_period: params[:within_period])
      end

      TransactionSet.new(transactions: applicable_transactions)
    end

    def cash_flow(account_id)
      transactions = relation(:transactions)
      accounts = relation(:accounts).restrict(id: account_id)
      to_models(
        transactions.join(accounts, { account_id: :id }),
        PlannedTransaction
      ).sort_by(&:name)
    end

    def all_transaction_tag_sets
      to_models(relation(:transaction_tag_sets), TransactionTagSet)
    end

    def delete_transaction(id)
      @persistence.delete(:transactions, relation(:transactions).restrict(id: id))
    end

    def tag_index
      to_models(
        relation(:transaction_tags),
        TransactionTag
      ).group_by(&:transaction_id)
    end

    private

    def partition_transactions_by_pay_period(transactions, in_period:)
      if transactions.count < 2
        return TransactionSet.new(transactions: transactions)
      end

      income_dates = transactions.select { |t| t.amount > 0 }.map(&:date)
      all_dates = [in_period.begin] + income_dates.drop(1) + [in_period.end]
      income_periods = all_dates.each_cons(2).map { |dates| Range.new(dates[0].to_date, dates[1].to_date - 1, exclude_end: true) }

      income_periods.map do |period|
        PayPeriod.new(
          incomes: transactions.select { |t| t.amount > 0 && period.include?(t.date.to_date) },
          transactions: transactions.select { |t| t.amount <= 0 && period.include?(t.date.to_date) },
          date_range: period
        )
      end
    end

    def transactions_for_tags(tags, tag_index, intersection: false)
      transaction_relation = if intersection
                               transaction_ids = tag_index.select do |_, t|
                                 (t.map(&:name) & tags).count == tags.count
                               end.keys
                               relation(:transactions).restrict(id: transaction_ids)
                             else
                               _transactions_for_tags(tags)
                             end

      to_models(transaction_relation, PlannedTransaction)
    end

    def transactions_for_tag_sets(tag_set_ids)
      tag_sets = to_models(
        relation(:transaction_tag_sets).restrict(id: tag_set_ids),
        TransactionTagSet
      )

      return [] if tag_sets.empty?

      to_models(
        _transactions_for_tags(tag_sets.first.tags),
        PlannedTransaction
      )
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