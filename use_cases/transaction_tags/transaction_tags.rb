# frozen_string_literal: true

require_relative '../../memory_persistence'
require_relative '../../data_interactor'
require_relative '../../types'

module UseCase
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
end