# frozen_string_literal: true

require_relative '../test_application'
require_relative './actions'
require_relative './propositions'

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
      ApplicationActions::CREATE_TAG_SET
    ]

    ApplicationActions::Sequences.new(
      test_actions,
      fresh_application: -> { test_application }
    ).check! do |test_app|
      tag_sets = test_app.all_transactions[:tag_sets]

      next if tag_sets.empty?

      tag_set_subject = any(arrays(of: element_of(tag_sets)), name: 'Tag Set Subject')
      transactions = test_app
                     .transactions({
                                     transaction_tag_set: tag_set_subject
                                   })[:transactions]

      tags = tag_set_subject.flat_map(&:tags)

      expect(
        Propositions::FilteredTransactionsRespectTags(
          transactions.transactions,
          tags,
          test_app
        )
      ).to be(true)
    end
  end
end
