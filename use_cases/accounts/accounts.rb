# frozen_string_literal: true

require_relative '../../memory_persistence'
require_relative '../../data_interactor'
require_relative '../../types'

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
end