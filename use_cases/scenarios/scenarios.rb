module UseCase
  class Scenarios
    extend Forwardable
    def_delegators :@data_interactor, :to_models, :relation

    def initialize(persistence: MemoryPersistence.new)
      @persistence = persistence
      @data_interactor = DataInteractor.new(persistence)
    end

    def create_scenario(params)
    end
  end
end