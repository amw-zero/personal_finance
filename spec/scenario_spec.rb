require_relative './test_application'

describe 'Scenarios' do
  describe 'Making a scenario' do
    it 'is able to be created' do
      test_app = test_application

      test_app.execute_and_render(test_app.interactions[:create_scenario], {
        name: 'Test scenario'
      })
    end
  end

  describe 'Cloning a scenario from an existing scenario' do
    it 'clones the transactions from the base scenario' do
      test_app = test_application

      test_app.execute_and_render(test_app.interactions[:create_scenario], {
        name: 'Scenario'
      })
      initial_scenario = test_app.scenarios.first

      test_app.execute_and_render(test_app.interactions[:create_transaction], {
        name: 'test',
        scenario_id: initial_scenario.id,
        amount: 50.0,
        currency: :usd,
        account_id: 1,
        recurrence_rule: 'Test',
        occurs_on: ''
      })

      test_app.execute_and_render(test_app.interactions[:create_scenario], { 
        name: 'Test scenario',
        clone_from_id: initial_scenario.id
      })
      cloned_scenario = (test_app.scenarios - [initial_scenario]).first

      initial_transactions_view = test_app.execute_and_render(test_app.interactions[:view_transactions], { scenario_id: initial_scenario.id })
      cloned_transactions_view = test_app.execute_and_render(test_app.interactions[:view_transactions], { scenario_id: cloned_scenario.id })

      initial_transactions = initial_transactions_view.data[:transactions].transactions
      cloned_transactions = cloned_transactions_view.data[:transactions].transactions

      def without_ids(t)
        t.attributes.except(:id, :scenario_id)
      end

      expect(cloned_transactions.map { |t| without_ids(t) }).to eq(initial_transactions.map { |t| without_ids(t) })
    end
  end

  describe 'Filtering transactions to a scenario' do
  end

  describe 'Transactions are filtered by the first scenario by default' do
  end
end