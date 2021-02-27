# frozen_string_literal: true

require 'bmg'
require 'bmg/sequel'
require 'dry-struct'
require 'forwardable'
require 'pg'
require 'rrule'

require_relative 'data_interactor'
require_relative 'memory_persistence'
require_relative 'types'
require_relative 'use_cases/transactions/transactions'
require_relative 'use_cases/transactions/create_transaction_view'
require_relative 'use_cases/transactions/transactions_view'
require_relative 'use_cases/transactions/layout_view'

# Thoughts: It is easier to never build nested data. Using the pattern like the
# tag_index, you can pull the associated data when you need.
# i.e. Alloy style attributes are separate relations

# The top-level module for the Personal Finance app
module PersonalFinance
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
  end

  # The top-level Personal Finance application
  class Application
    extend Forwardable
    def_delegators :@data_interactor, :to_models, :relation
    def_delegators :transactions_use_case, :delete_transaction, :transactions, :create_transaction, :create_transaction_from_params, :tag_index

    attr_reader :endpoints, :use_cases, :interactions

    def initialize(log_level: :quiet, persistence: MemoryPersistence.new)
      @accounts = []
      @linked_accounts = []
      @persistence = persistence
      @data_interactor = DataInteractor.new(persistence)
      @log_level = log_level ? log_level.to_sym : :quiet
      @use_cases = {
        accounts: UseCase::Accounts.new(persistence: persistence),
        people: UseCase::People.new(persistence: persistence),
        transactions: ::UseCase::Transactions.new(persistence: persistence),
        transaction_tags: UseCase::TransactionTags.new(persistence: persistence),
        transaction_tag_sets: UseCase::TransactionTagSets.new(persistence: persistence)
      }
      @interactions = {
        create_transaction: {
          name: '/test/transactions',
          type: :create,
          # Create "schema" type here using Dry::Struct?
          fields: [
            {
              type: :decimal,
              name: :amount
            },
            {
              type: :string,
              name: :name
            },
            {
              type: :date,
              name: :occurs_on
            }
          ]
        },
        view_transactions: {
          name: '/test/transactions',
          type: :view
        },
        new_transaction: {
          name: '/test/transactions/new',
          type: :view
        }
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

    def execute(interaction, params = {})
      case [interaction[:name], interaction[:type]]
      when ['/test/transactions', :create]
        create_transaction_from_params(**params)
        data = transactions({})
        LayoutView.new(
          TransactionsView.new(
            new_transaction_interaction: interactions[:new_transaction],
            accounts: accounts, 
            data: data, 
            params: {},
            interactions: interactions
          )
        )
      when ['/test/transactions', :view]
        data = transactions(params)
        LayoutView.new(
          TransactionsView.new(
            new_transaction_interaction: interactions[:new_transaction],
            accounts: accounts, 
            data: data, 
            params: params,
            interactions: interactions,
          )
        )
      when ['/test/transactions/new', :view]
        LayoutView.new(
          CreateTransactionView.new(
            interactions[:create_transaction], 
            accounts: accounts
          )
        )
      else
        raise "Attempted to execute unknown interaction: #{interaction[:name]}"
      end
    end

    def create_transaction_view
      CreateTransactionView.new(interactions[:create_transaction])
    end

    private

    def log(msg)
      puts msg if @log_level == :verbose
    end
  end
end
