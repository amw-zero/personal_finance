# frozen_string_literal: true

require_relative '../test_application'
require_relative './actions'

require 'hypothesis'

# View         ==> Presentation
# Interaction  ==> Interaction with application (i.e. server, but in an abstract way. A change of application state)
# UseCase      ==> Application coordination logic
describe 'Viewing Transactions within a Period' do
  include Hypothesis
  include Hypothesis::Possibilities

  specify do
    test_app = test_application
    starting_transactions = test_app.all_transactions.transactions

    view = test_app.create_transaction_view
    interaction = view.create_transaction_interaction
    params = interaction[:fields].map do |field|
      case field[:type]
      when 'decimal'
        [field[:name].to_sym, 10.0]
      when 'string'
        [field[:name].to_sym, 'Test']
      end
    end.to_h

    params.merge!({ account_id: 1, currency: :usd, recurrence_rule: 'Testing'})

    new_transaction = test_app.execute(interaction, params)

    expect(test_app.all_transactions.transactions).to eq(starting_transactions + [new_transaction])
  end
end