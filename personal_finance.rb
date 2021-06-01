# frozen_string_literal: true

# Todo: Make Scenarios#create_transaction. Remove scenario dropdown from transactions form.
# Bounded context - creating a transaction is different when in the scenarios context

# Fix filtering, demo filter does not persist between views

# Investigate state machine , State + Interaction design. One test which just traverses state graph, asserting properties

require 'bmg'
require 'bmg/sequel'
require 'dry-struct'
require 'forwardable'
require 'pg'
require 'rrule'

require_relative 'data_interactor'
require_relative 'memory_persistence'
require_relative 'types'

require_relative 'use_cases/accounts/accounts'

require_relative 'use_cases/scenarios/scenarios'
require_relative 'use_cases/scenarios/scenario_form_view'

require_relative 'use_cases/transactions/transactions'
require_relative 'use_cases/transactions/create_transaction_view'
require_relative 'use_cases/transactions/transactions_view'

# TODO: This doesn't belong in Transactions use case
require_relative 'use_cases/transactions/layout_view'

require_relative 'use_cases/transaction_tags/transaction_tag_form_view'
require_relative 'use_cases/transaction_tags/transaction_tags'

require_relative 'use_cases/transaction_tag_sets/transaction_tag_sets'

# Thoughts: It is easier to never build nested data. Using the pattern like the
# tag_index, you can pull the associated data when you need.

# i.e. Alloy style attributes are separate relations

# The top-level module for the Personal Finance app
module PersonalFinance
  # The top-level Personal Finance application
  class Application
    extend Forwardable
    def_delegators :@data_interactor, :to_models, :relation
    def_delegators :accounts_use_case, :accounts, :create_account
    def_delegators :scenarios_use_case, :create_scenario, :scenarios, :default_scenario
    def_delegators :transactions_use_case, :delete_transaction, :transactions, :create_transaction,
                   :create_transaction_from_params, :tag_index
    def_delegators :transaction_tags_use_case, :tag_transaction

    attr_reader :endpoints, :use_cases, :interactions

    def initialize(log_level: :quiet, persistence: MemoryPersistence.new)
      @accounts = []
      @linked_accounts = []
      @persistence = persistence
      @data_interactor = DataInteractor.new(persistence)
      @log_level = log_level ? log_level.to_sym : :quiet
      transactions_use_case = UseCase::Transactions.new(persistence: persistence)
      @use_cases = {
        accounts: UseCase::Accounts.new(persistence: persistence),
        scenarios: UseCase::Scenarios.new(persistence: persistence, transactions_use_case: transactions_use_case),
        transactions: transactions_use_case,
        transaction_tags: UseCase::TransactionTags.new(persistence: persistence),
        transaction_tag_sets: UseCase::TransactionTagSets.new(persistence: persistence)
      }
      @interactions = {
        root: {
          name: '/',
          type: :view
        },
        create_transaction: {
          name: '/transactions',
          type: :create,
          # Create "schema" type here using Dry::Struct?
          fields: [
            {
              type: :account,
              name: :account
            },
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
          type: :view
        },
        new_scenario: {
          name: '/scenarios/new',
          type: :view
        },
        create_scenario: {
          name: '/scenarios',
          type: :create,
          fields: [
            {
              type: :string,
              name: :name
            },
            {
              type: :scenario,
              name: :clone_from
            }
          ]
        }
      }
    end

    def execute(interaction, params = {})
      result = case [interaction[:name], interaction[:type]]
               when ['/', :view]
                 interactions[:view_transactions]
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
               when ['/scenarios', :create]
                create_scenario(params)

                interactions[:view_transactions]
              when ['/scenarios/new', :view]
                scenarios_form(params)
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

    def create_transaction_tag_set(params)
      @use_cases[:transaction_tag_sets].create_transaction_tag_set(params)
    end

    private

    def transaction_tags_use_case
      @use_cases[:transaction_tags]
    end

    def accounts_use_case
      @use_cases[:accounts]
    end

    def transactions_use_case
      @use_cases[:transactions]
    end

    def scenarios_use_case
      @use_cases[:scenarios]
    end

    def transaction_tags
      relation(:transaction_tags).map do |data|
        TransactionTag.new(data)
      end.uniq(&:name)
    end

    def transactions_view(interaction_name, params, is_schedule: false)
      if !params[:scenario_id] && default_scenario
        params[:scenario_id] = default_scenario.id
      end
      data = transactions(params, is_schedule: is_schedule)
      TransactionsView.new(
        new_transaction_interaction: interactions[:new_transaction],
        accounts: accounts,
        data: data,
        params: params,
        page: interaction_name,
        interactions: interactions,
        scenarios: scenarios
      )
    end

    def create_transaction_view
      CreateTransactionView.new(
        interactions: interactions,
        accounts: accounts,
        scenarios: scenarios
      )
    end

    def transaction_tag_form(params)
      TransactionTagFormView.new(
        transaction: to_models(relation(:transactions).restrict(id: params[:id].to_i), PlannedTransaction).first,
        interactions: interactions
      )
    end

    def scenarios_form(params)
      ScenarioFormView.new(
        interactions: interactions,
        scenarios: scenarios
      )
    end

    def log(msg)
      puts msg if @log_level == :verbose
    end
  end
end
