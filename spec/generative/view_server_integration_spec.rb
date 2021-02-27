# frozen_string_literal: true

require_relative '../test_application'
require_relative './actions'
require_relative '../../view'

require 'hypothesis'

# View         ==> Presentation
# Interaction  ==> Interaction with application (i.e. server, but in an abstract way. A change of application state)
# UseCase      ==> Application coordination logic
describe 'Viewing Transactions within a Period' do
  include Hypothesis
  include Hypothesis::Possibilities

  specify do
    test_app = test_application
    starting_transactions = test_app.all_transactions[:transactions].transactions

    # test_app
    #   .execute(test_app.interactions[:view_transactions])
    #   .new_transaction
    #   .execute({})

    view = test_app.execute(test_app.interactions[:view_transactions])
    expect(ErbRenderer.new(view).render).to_not be_nil

    interaction = test_app.interactions[:new_transaction]
    view = test_app.execute(interaction, {})
    expect(ErbRenderer.new(view).render).to_not be_nil

    interaction = test_app.interactions[:create_transaction]
    params = interaction[:fields].map do |field|
      value = case field[:type]
              when :decimal
                10.0
              when :string
                'Test'
              when :date
                '2020-01-03'
              end

      [field[:name], value]
    end.to_h
    params.merge!({ account_id: 1, currency: :usd, recurrence_rule: 'Testing' })

    view = test_app.execute(interaction, params)

    after_transactions = test_app.all_transactions[:transactions].transactions
    created_transactions = after_transactions - starting_transactions
    created_transaction = created_transactions.first
    expected_transaction = PlannedTransaction.new(params)

    expect(created_transaction.attributes.except(:id)).to eq(expected_transaction.attributes)
    expect(created_transactions.count).to eq(1)
    expect(ErbRenderer.new(view).render).to_not be_nil
  end
end
