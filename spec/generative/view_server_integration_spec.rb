# frozen_string_literal: true

require_relative '../test_application'
require_relative './actions'
require_relative './interaction_params'
require_relative '../../view'

require 'hypothesis'

# View         ==> Presentation
# Interaction  ==> Interaction with application (i.e. server, but in an abstract way. A change of application state)
# UseCase      ==> Application coordination logic
describe 'Viewing Transactions within a Period' do
  include Hypothesis
  include Hypothesis::Possibilities

  specify do
    test_actions = [
      ApplicationActions::CREATE_ACCOUNT,
      ApplicationActions::CREATE_SCENARIO,
      ApplicationActions::CREATE_TRANSACTION
    ]

    max_transaction_count = 0

    ApplicationActions::Sequences.new(
      test_actions,
      fresh_application: -> { test_application }
    ).check!(max_checks: 200) do |test_app, _executed|
      starting_transactions = test_app.execute_and_render(test_app.interactions[:view_transactions]).data[:transactions].transactions

      # test_app
      #   .execute(test_app.interactions[:view_transactions])
      #   .new_transaction
      #   .execute({})

      view = test_app.execute_and_render(test_app.interactions[:view_transactions])

      interaction = test_app.interactions[:new_transaction]
      view = test_app.execute_and_render(interaction, {})

      # Create transaction
      interaction = test_app.interactions[:create_transaction]
      params = interaction_params(interaction)
      params.merge!({ account_id: 1, currency: :usd, recurrence_rule: 'Testing', scenario_id: 1 })

      view = test_app.execute_and_render(interaction, params)

      after_transactions = test_app.execute_and_render(test_app.interactions[:view_transactions]).data[:transactions].transactions
      expect(after_transactions.all? { |t| t.scenario_id == 1 }).to eq(true)

      created_transactions = after_transactions - starting_transactions
      created_transaction = created_transactions.first

      next if created_transaction.nil?

      expected_params = params.dup
      expected_params[:occurs_on] = Date.parse(expected_params[:occurs_on]) - 7 * 1000

      expected_transaction = PlannedTransaction.new(expected_params)

      expect(created_transaction.attributes.except(:id)).to eq(expected_transaction.attributes)
      expect(created_transactions.count).to eq(1)
      expect(ErbRenderer.new(view).render).to_not be_nil

      # Delete transaction
      deleted_id = after_transactions.first.id
      next_interaction = test_app.execute_and_render(test_app.interactions[:delete_transaction], { id: deleted_id })

      deleted_transaction = test_app.execute_and_render(test_app.interactions[:view_transactions]).data[:transactions].transactions.find do |t|
        t.id == deleted_id
      end
      expect(deleted_transaction).to be_nil
      view = test_app.execute_and_render(next_interaction, {})
    end
  end
end
