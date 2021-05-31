module UseCase
  class Scenarios
    extend Forwardable
    def_delegators :@data_interactor, :to_models, :relation

    def initialize(persistence: MemoryPersistence.new, transactions_use_case:)
      @persistence = persistence
      @data_interactor = DataInteractor.new(persistence)
      @transactions_use_case = transactions_use_case
    end

    def scenarios
      to_models(
        relation(:scenarios),
        Scenario
      ).sort_by(&:name)
    end

    def create_scenario(params)
      scenario = Scenario.new(name: params[:name])
      @persistence.persist(:scenarios, scenario.attributes)
      created_scenario = to_models(relation(:scenarios).restrict(name: params[:name]), Scenario).first

      if params[:clone_from_id] != 'none'
        transactions = to_models(
          relation(:transactions)
            .restrict(scenario_id: params[:clone_from_id].to_i),
          PlannedTransaction
        )

        transactions.each do |transaction|
          attrs = transaction.attributes.dup
          attrs[:scenario_id] = created_scenario.id
          attrs.delete(:id)

          clone = PlannedTransaction.new(attrs)
          @transactions_use_case.persist_transaction(clone)
        end
      end
    end

    def default_scenario
      relation(:scenarios).restrict(id: 1).first&.then { |data| Scenario.new(data) }
    end
  end
end