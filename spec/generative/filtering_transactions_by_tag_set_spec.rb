# frozen_string_literal: true

require_relative '../test_application'
require_relative './actions'
require 'hypothesis'

describe 'Transactions by Tag Set' do
  include Hypothesis
  include Hypothesis::Possibilities

  specify do
    hypothesis(max_valid_test_cases: 100, phases: Phase.excluding(:shrink)) do
      test_app = test_application

      test_actions = [
        ApplicationActions::CREATE_ACCOUNT, 
        ApplicationActions::CREATE_TRANSACTION, 
        ApplicationActions::CREATE_TAG,
        ApplicationActions::CREATE_TAG_SET,
      ]

      any(
        arrays(
          of: element_of(test_actions),
          min_size: 5,
          max_size: 100
        ), 
        name: 'Actions'
      ).each do |action|
        ApplicationActions.execute(action, in_app: test_app)
      end

      tag_sets = test_app.all_transaction_tag_sets

      next if tag_sets.empty?

      tag_set_subject = any(arrays(of: element_of(tag_sets)))

      transactions = test_app.use_cases[:transactions].transactions({
        transaction_tagset: tag_set_subject
      }).transactions

      if (tag_set_subject & tag_sets)
        expect(transactions.count).to_not be(0)
      end
    end
  end
end