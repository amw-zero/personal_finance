# frozen_string_literal: true

require_relative '../test_application'
require_relative './actions'

# TODO: Would be nice to have hypothesis abstracted
# by ApplicationActions::Sequences
require 'hypothesis'

describe 'Transactions by Tag Set' do
  include Hypothesis
  include Hypothesis::Possibilities

  specify do
    test_actions = [
      ApplicationActions::CREATE_ACCOUNT,
      ApplicationActions::CREATE_TRANSACTION,
      ApplicationActions::CREATE_TAG,
      ApplicationActions::CREATE_TAG_SET,
    ]

    ApplicationActions::Sequences.new(
      test_actions,
      fresh_application: -> { test_application }
    ).check! do |test_app|
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