# frozen_string_literal: true

require 'dry-struct'
require 'forwardable'
require 'bmg'
require 'pg'
require 'bmg/sequel'

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
      when 'PersonalFinance::Transaction'
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
              # TODO: These type coercions can be a source of bugs
              # add to application kernel, should only be:
              # application.create_transaction(params)
              # Can keep the same API internally with the above as an "anti-corruption" wrapper
              # which handles web concerns
              create_transaction(
                name: params[:name],
                account_id: params[:account_id].to_i,
                amount: params[:amount].to_f,
                currency: params[:currency].to_sym,
                day_of_month: params[:day_of_month].to_i
              )
            end
          },
          {
            method: :get,
            path: '/transactions',
            action: lambda do |params|
              if params[:transaction_tag]
                transactions_for_tags(
                  params[:transaction_tag],
                  @tag_index,
                  intersection: params[:intersection] == 'true'
                )
              elsif params[:transaction_tag_set]
                transactions_for_tag_sets(params[:transaction_tag_set])
              elsif params[:account]
                cash_flow(params[:account].to_i)
              else
                transactions
              end
            end
          }
        ]
      end

      def create_transaction(name:, account_id:, amount:, currency:, day_of_month:)
        Transaction.new(
          name: name,
          account_id: account_id,
          amount: amount,
          currency: currency,
          day_of_month: day_of_month
        ).tap do |i|
          @persistence.persist(:transactions, persistable_transation(i))
        end
      end

      def transactions
        to_models(
          relation(:transactions),
          Transaction
        ).sort_by(&:day_of_month)
      end

      def cash_flow(account_id)
        transactions = relation(:transactions)
        accounts = relation(:accounts).restrict(id: account_id)
        to_models(
          transactions.join(accounts, { account_id: :id }),
          Transaction
        ).sort_by(&:day_of_month)
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

        to_models(transaction_relation, Transaction)
      end

      private

      def persistable_transation(transaction)
        # TODO: the attributes are mutable here, and this is surprising and confusing
        # Persisting this later one modifies the attributes which modifies the struct.
        # Terrifying.
        transaction.attributes.merge!({ currency: transaction.currency.to_s })
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

    def create_transaction(name:, account_id:, amount:, currency:, day_of_month:)
      @use_cases[:transactions]
        .create_transaction(
          name: name,
          account_id: account_id,
          amount: amount,
          currency: currency,
          day_of_month: day_of_month
        )
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

    def transactions
      @use_cases[:transactions].transactions
    end

    def cash_flow(account_id)
      @use_cases[:transactions].cash_flow(account_id)
    end

    def transactions_for_tags(tags, tag_index, intersection: false)
      transaction_relation = if intersection
                               transaction_ids = tag_index.select do |_, t|
                                 (t.map(&:name) & tags).count == tags.count
                               end.keys
                               relation(:transactions).restrict(id: transaction_ids)
                             else
                               _transaction_for_tags(tags)
                             end

      transactions = to_models(transaction_relation, Transaction)

      [{ title: 'Current Tag', tags: tags, transaction_set: TransactionSet.new(transactions: transactions) }]
    end

    def _transaction_for_tags(tags)
      transactions = relation(:transactions)
      tags = relation(:transaction_tags).restrict(name: tags).rename(name: :tag_name)

      # TODO: Bug here - calling to_models on this will caus the Transaction to get the id of the
      # TransactionTag because of the rename
      tags.join(transactions.rename(id: :transaction_id), [:transaction_id])
    end

    def transactions_for_tag_sets(tag_set_ids)
      tag_sets = to_models(
        relation(:transaction_tag_sets).restrict(id: tag_set_ids),
        TransactionTagSet
      )

      tag_sets.map do |tag_set|
        {
          title: tag_set.title,
          tags: tag_set.tags,
          transaction_set: TransactionSet.new(
            transactions: to_models(_transaction_for_tags(tag_set.tags), Transaction)
          )
        }
      end
    end

    def tag_index
      to_models(
        relation(:transaction_tags),
        TransactionTag
      ).group_by(&:transaction_id)
    end

    def transaction_tags
      relation(:transaction_tags).map do |data|
        TransactionTag.new(data)
      end.uniq(&:name)
    end

    def transaction_tag_sets(ids)
      to_models(relation(:transaction_tag_sets).restrict(id: ids), TransactionTagSet)
    end

    def all_transaction_tag_sets
      to_models(relation(:transaction_tag_sets), TransactionTagSet)
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

  # A financial transaction, e.g. an expense or an income
  class Transaction < Dry::Struct
    attribute? :id, Types::Integer
    attribute? :account, Account
    attribute :account_id, Types::Integer
    attribute :amount, Types::Float
    attribute :name, Types::String
    attribute :currency, Types::Value(:usd)
    attribute :day_of_month, Types::Integer
  end

  # A categorization of a transaction, e.g. "debt" or "house"
  class TransactionTag < Dry::Struct
    attribute? :id, Types::Integer
    attribute :transaction_id, Types::Integer
    attribute :name, Types::String
  end

  # A set of transactions
  class TransactionSet < Dry::Struct
    attribute :transactions, Types::Array(Transaction)

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
