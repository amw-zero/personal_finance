# frozen_string_literal: true

require_relative '../test_application'
require_relative './actions'
require_relative './propositions'
require 'hypothesis'

describe 'Transactions by Tag' do
  include Hypothesis
  include Hypothesis::Possibilities

  specify do
    test_actions = [
      ApplicationActions::CREATE_ACCOUNT,
      ApplicationActions::CREATE_SCENARIO,
      ApplicationActions::CREATE_TRANSACTION,
      ApplicationActions::CREATE_TAG
    ]
    ApplicationActions::Sequences.new(
      test_actions,
      fresh_application: -> { test_application }
    ).check! do |test_app|
      next if test_app.scenarios.empty?

      scenario = any(element_of(test_app.scenarios))
      next if scenario.nil?

      view = test_app
        .execute_and_render(
          test_app.interactions[:view_transactions],
          { scenario_id: scenario.id }
        )

      transaction_tags = 
        view.data[:tag_index]
        .values
        .uniq
        .flatten

      transactions = view.data[:transactions].transactions

      next if transaction_tags.empty?

      possible_tags = any(arrays(of: element_of(transaction_tags)))
      possible_tag_names = possible_tags.map(&:name)

      if !possible_tags.empty?
        expect(possible_tags.map(&:transaction_id) & transactions.map(&:id)).to_not be_empty
      end

      view = test_app
             .execute_and_render(test_app.interactions[:view_transactions], { transaction_tag: possible_tag_names })

      view = test_app
             .execute_and_render(test_app.interactions[:view_transactions_schedule], { transaction_tag: possible_tag_names })

      filtered_transactions = test_app
                              .transactions({ transaction_tag: possible_tag_names })[:transactions].transactions
      expect(
        Propositions.FilteredTransactionsRespectTags(
          filtered_transactions,
          possible_tag_names,
          test_app
        )
      ).to be(true)

      expect(Set.new(filtered_transactions).to_a).to eq(filtered_transactions)
    end
  end
end
