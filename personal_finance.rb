# frozen_string_literal: true

require 'bmg'
require 'bmg/sequel'
require 'dry-struct'
require 'forwardable'
require 'pg'
require 'rrule'


# Thoughts: It is easier to never build nested data. Using the pattern like the
# tag_index, you can pull the associated data when you need.

# Bring Dry::Struct types into scope
module Types
  include Dry::Types()
end

# The top-level module for the Personal Finance app
module PersonalFinance
  # Store relations in memory
  class MemoryPersistence
    attr_reader :people

    def initialize
      @relations = Hash.new(Bmg::Relation.new([]))
      @ids = Hash.new(1)
    end

    def relation_of(rel_name)
      @relations[rel_name]
    end

    def delete(relation, to_delete)
      @relations[relation] = Bmg::Relation.new(@relations[relation].to_a - to_delete.to_a)
    end

    def persist(relation, data)
      data[:id] = @ids[relation]
      @ids[relation] += 1
      @relations[relation] = @relations[relation].union(Bmg::Relation.new([data]))
    end
  end

  class DataInteractor
    def initialize(persistence)
      @persistence = persistence
    end

    def relation(name)
      @persistence.relation_of(name)
    end

    def to_models(relation, model_klass)
      #      log relation.to_sql if relation.is_a?(Bmg::Sql::Relation)
      case model_klass.to_s
      when 'PersonalFinance::PlannedTransaction'
        relation.map do |data|
          data[:currency] = data[:currency].to_sym
          model_klass.new(data)
        end
      when 'PersonalFinance::TransactionTagSet'
        relation.map do |data|
          data[:tags] = data[:tags].split(',')
          model_klass.new(data)
        end
      else
        relation.map do |data|
          model_klass.new(data)
        end
      end
    end
  end

  module UseCase
    class Accounts
      extend Forwardable
      def_delegators :@data_interactor, :to_models, :relation

      def initialize(persistence: MemoryPersistence.new)
        @persistence = persistence
        @data_interactor = DataInteractor.new(persistence)
      end

      def name
        :accounts
      end

      def endpoints
        [
          {
            method: :post,
            path: '/accounts',
            action: lambda do |params|
              create_account(params[:name])
            end
          },
          {
            method: :get,
            path: '/accounts',
            action: ->(_) { accounts }
          }
        ]
      end

      def create_account(name)
        Account.new(name: name).tap do |a|
          @persistence.persist(:accounts, a.attributes)
        end
      end

      def accounts
        to_models(
          relation(:accounts),
          Account
        )
      end
    end

    class People
      extend Forwardable
      def_delegators :@data_interactor, :to_models, :relation

      def initialize(persistence: MemoryPersistence.new)
        @persistence = persistence
        @data_interactor = DataInteractor.new(persistence)
      end

      def endpoints
        [
          {
            method: :post,
            path: '/people',
            action: lambda do |params|
              create_person(params[:name])
            end
          }
        ]
      end

      def create_person(name)
        Person.new(name: name).tap do |p|
          @persistence.persist(:people, p.attributes)
        end
      end
    end

    class TransactionTags
      extend Forwardable
      def_delegators :@data_interactor, :to_models, :relation

      def initialize(persistence: MemoryPersistence.new)
        @persistence = persistence
        @data_interactor = DataInteractor.new(persistence)
      end

      def endpoints
        [
          {
            method: :post,
            path: '/transaction_tags',
            return: '/transactions',
            action: ->(params) { tag_transaction(params[:transaction_id].to_i, tag: params[:name]) }
          }
        ]
      end

      def tag_transaction(transaction_id, tag:)
        TransactionTag.new(
          transaction_id: transaction_id,
          name: tag
        ).tap do |i|
          @persistence.persist(:transaction_tags, i.attributes)
        end
      end
    end

    class TransactionTagSets
      extend Forwardable
      def_delegators :@data_interactor, :to_models, :relation

      def initialize(persistence: MemoryPersistence.new)
        @persistence = persistence
        @data_interactor = DataInteractor.new(persistence)
      end

      def endpoints
        [
          {
            method: :post,
            path: '/transaction_tag_sets',
            return: '/transactions',
            action: ->(params) { create_transaction_tag_set(params) }
          }
        ]
      end

      def create_transaction_tag_set(params)
        title = params[:title]
        tags = params[:transaction_tag]
        TransactionTagSet.new(title: title, tags: tags).tap do |t|
          t.attributes[:tags] = t.attributes[:tags].join(',')
          @persistence.persist(:transaction_tag_sets, t.attributes)
        end
      end
    end

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
              today = Date.today
              first_of_month = Date.new(today.year, today.month, 1)
              end_of_month = Date.new(today.year, today.month + 1, 1) - 1

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
        PlannedTransaction.new(
          name: name,
          account_id: account_id,
          amount: amount,
          currency: currency,
          recurrence_rule: recurrence_rule,
          created_at: DateTime.now
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
            currency: transaction.currency.to_s,
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

  # The top-level Personal Finance application
  class Application
    extend Forwardable
    def_delegators :@data_interactor, :to_models, :relation
    def_delegators :transactions_use_case, :delete_transaction, :transactions, :create_transaction, :tag_index

    attr_reader :endpoints, :use_cases

    def initialize(log_level: :quiet, persistence: MemoryPersistence.new)
      @accounts = []
      @linked_accounts = []
      @persistence = persistence
      @data_interactor = DataInteractor.new(persistence)
      @log_level = log_level ? log_level.to_sym : :quiet
      @use_cases = {
        accounts: UseCase::Accounts.new(persistence: persistence),
        people: UseCase::People.new(persistence: persistence),
        transactions: UseCase::Transactions.new(persistence: persistence),
        transaction_tags: UseCase::TransactionTags.new(persistence: persistence),
        transaction_tag_sets: UseCase::TransactionTagSets.new(persistence: persistence)
      }
    end

    def create_person(name)
      @use_cases[:people].create_person(name)
    end

    def create_account(name)
      @use_cases[:accounts].create_account(name)
    end

    def link_account(person:, account:)
      LinkedAccount.new(person: person, account: account).tap do |la|
        @linked_accounts << la
      end
    end    

    def tag_transaction(transaction_id, tag:)
      @use_cases[:transaction_tags].tag_transaction(transaction_id, tag: tag)
    end

    def create_transaction_tag_set(params)
      @use_cases[:transaction_tag_sets].create_transaction_tag_set(params)
    end

    def people
      to_models(
        relation(:people),
        Person
      )
    end

    def accounts
      @use_cases[:accounts].accounts
    end

    def all_transactions
      @use_cases[:transactions].transactions({})
    end

    def transactions_use_case
      @use_cases[:transactions]
    end

    def cash_flow(account_id)
      @use_cases[:transactions].cash_flow(account_id)
    end

    def transactions_for_tag_sets(tag_set_ids)
      @use_cases[:transactions].transactions_for_tag_sets(tag_set_ids)
    end

    def all_transaction_tag_sets
      @use_cases[:transactions].all_transaction_tag_sets
    end

    def transaction_tags
      relation(:transaction_tags).map do |data|
        TransactionTag.new(data)
      end.uniq(&:name)
    end

    private

    def log(msg)
      puts msg if @log_level == :verbose
    end
  end

  # A person
  class Person < Dry::Struct
    attribute? :id, Types::Integer
    attribute :name, Types::String
  end

  # A finance account
  class Account < Dry::Struct
    attribute? :id, Types::Integer
    attribute :name, Types::String
  end

  # A relationship between a Person and an Account
  class LinkedAccount < Dry::Struct
    attribute :person, Person
    attribute :account, Account
  end

  # A financial transaction, e.g. an expense or an income. "Planned" because it
  # is not an actual transaction between accounts, but rather can have an associated
  # recurrence rule which represents a conceptual infinite set of Transactions.
  class PlannedTransaction < Dry::Struct
    attribute? :id, Types::Integer
    attribute? :account, Account
    attribute :account_id, Types::Integer
    attribute :amount, Types::Float
    attribute :name, Types::String
    attribute :currency, Types::Value(:usd)
    attribute :recurrence_rule, Types::String
    attribute :created_at, Types.Constructor(DateTime) { |created_at| created_at }

    def occurrences_within(period)
      start_date = period.begin.to_datetime

      RRule.parse(recurrence_rule, dtstart: created_at).between(
        start_date,
        period.end.to_datetime
      )
    end
  end

  # A "concrete" transaction, i.e. one that occurs on a specific date. Since
  # PlannedTransactions are defined with recurrence rules that specify when they actually occur,
  # Transaction is one instance of the recurrence rule.
  class Transaction < Dry::Struct
    extend Forwardable
    def_delegators :planned_transaction, :name, :amount 

    attribute :date, Types::String
    attribute :planned_transaction, PlannedTransaction
  end

  # A categorization of a transaction, e.g. "debt" or "house"
  class TransactionTag < Dry::Struct
    attribute? :id, Types::Integer
    attribute :transaction_id, Types::Integer
    attribute :name, Types::String
  end

  # A set of transactions
  # TODO: Rename or at least alias to Budget
  # There might be a use case for sets of Transactions that aren't
  # semantically budgets
  class TransactionSet < Dry::Struct
    attribute :transactions, Types::Array(PlannedTransaction) | Types::Array(Transaction)

    def sum
      transactions.map(&:amount).sum.round(2)
    end
  end

  # A set of transaction tags
  class TransactionTagSet < Dry::Struct
    attribute? :id, Types::Integer
    attribute :title, Types::String
    attribute :tags, Types::Array(Types::String)
  end
end
