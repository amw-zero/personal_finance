# frozen_string_literal: true

require_relative '../../memory_persistence'
require_relative '../../data_interactor'
require_relative '../../types'

module UseCase
  class TransactionTagSets
    extend Forwardable
    def_delegators :@data_interactor, :to_models, :relation

    def initialize(persistence: MemoryPersistence.new)
      @persistence = persistence
      @data_interactor = DataInteractor.new(persistence)
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
