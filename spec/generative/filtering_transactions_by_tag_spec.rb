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
      ApplicationActions::CREATE_TRANSACTION,
      ApplicationActions::CREATE_TAG
    ]
    ApplicationActions::Sequences.new(
      test_actions,
      fresh_application: -> { test_application }
    ).check! do |test_app|
      next if test_app.transaction_tags.empty?

      possible_tags = any(arrays(of: element_of(test_app.transaction_tags))).map(&:name)

      view = test_app
             .execute(test_app.interactions[:view_transactions], { transaction_tag: possible_tags })
      expect(ErbRenderer.new(view).render).to_not be_nil

      view = test_app
             .execute(test_app.interactions[:view_transactions_schedule], { transaction_tag: possible_tags })

      expect(ErbRenderer.new(view).render).to_not be_nil

      filtered_transactions = test_app
                              .transactions({ transaction_tag: possible_tags })[:transactions].transactions
      expect(
        Propositions.FilteredTransactionsRespectTags(
          filtered_transactions,
          possible_tags,
          test_app
        )
      ).to be(true)

      expect(Set.new(filtered_transactions).to_a).to eq(filtered_transactions)
    end
  end
end
