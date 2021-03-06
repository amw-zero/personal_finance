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
require_relative 'use_cases/transaction_tags/transaction_tag_form_view'

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
    def_delegators :transactions_use_case, :delete_transaction, :transactions, :create_transaction,
                   :create_transaction_from_params, :tag_index

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
          name: '/transactions',
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
            },
            {
              type: :string,
              name: :currency
            },
            {
              type: :string,
              name: :recurrence_rule
            }
          ]
        },
        view_transactions: {
          name: '/transactions',
          type: :view
        },
        view_transactions_schedule: {
          name: '/transactions/schedule',
          type: :view
        },
        new_transaction: {
          name: '/transactions/new',
          type: :view
        },
        delete_transaction: {
          name: '/transactions/:id',
          type: :delete
        },
        tag_transaction: {
          name: '/transaction_tags',
          type: :create,
          fields: [
            {
              type: :string,
              name: :name
            }
          ]
        },
        new_transaction_tag: {
          name: '/transactions/:id/tags/create',
          type: :view,
        }
      }
    end

    def create_person(name)
      @use_cases[:people].create_person(name)
    end

    def create_account(name)
      @use_cases[:accounts].create_account(name)
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

    def all_transaction_tag_sets
      @use_cases[:transactions].all_transaction_tag_sets
    end

    def transaction_tags
      relation(:transaction_tags).map do |data|
        TransactionTag.new(data)
      end.uniq(&:name)
    end

    def execute(interaction, params = {})
      result = case [interaction[:name], interaction[:type]]
               when ['/transactions', :create]
                 create_transaction_from_params(params)

                 transactions_view(:view_transactions, {})
               when ['/transactions', :view]
                 transactions_view(:view_transactions, params)
               when ['/transactions/schedule', :view]
                 transactions_view(:view_transactions_schedule, params, is_schedule: true)
               when ['/transactions/new', :view]
                 create_transaction_view
               when ['/transactions/:id', :delete]
                 delete_transaction(params)

                 interactions[:view_transactions]
               when ['/transactions/:id/tags/create', :view]
                transaction_tag_form(params)
               when ['/transaction_tags', :create]
                 tag_transaction(params[:transaction_id].to_i, tag: params[:name])

                 interactions[:view_transactions]
               else
                 raise "Attempted to execute unknown interaction: #{interaction[:name]}"
               end

      if result.is_a?(Hash)
        result

      else
        content = result
        LayoutView.new(content, interactions: interactions)
      end
    end

    private

    def transactions_view(interaction_name, params, is_schedule: false)
      data = transactions(params, is_schedule: is_schedule)
      TransactionsView.new(
        new_transaction_interaction: interactions[:new_transaction],
        accounts: accounts,
        data: data,
        params: params,
        page: interaction_name,
        interactions: interactions
      )
    end

    def create_transaction_view
      CreateTransactionView.new(
        interactions: interactions,
        accounts: accounts
      )
    end

    def transaction_tag_form(params)
      TransactionTagFormView.new(
        transaction: all_transactions[:transactions].transactions.find { |t| t.id == params[:id].to_i },
        interactions: interactions,
      )
    end

    def log(msg)
      puts msg if @log_level == :verbose
    end
  end
end
