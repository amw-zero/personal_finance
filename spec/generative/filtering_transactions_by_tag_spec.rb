# frozen_string_literal: true

require_relative '../test_application'
require_relative './actions'
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
      max_count = if test_app.transaction_tags.count == 0
                    2
                  else
                    test_app.transaction_tags.count
                  end
      tag_sample_count = any integers(min: 1, max: max_count)
      possible_tags = test_app.transaction_tags.sample(tag_sample_count).map(&:name)

      # puts "Sampled #{tag_sample_count} tags: #{possible_tags}"

      filtered_transactions = test_app
                              .use_cases[:transactions]
                              .transactions({ transaction_tag: possible_tags })
                              .transactions

      # puts "Got #{filtered_transactions.count} filtered transactions"

      filtered_transactions.each do |transaction|
        transaction_tags = test_app.tag_index[transaction.id]

        expect(transaction_tags).to_not be_nil

        tags = transaction_tags.map(&:name)
        same_tags = tags & possible_tags
        expect(same_tags.length).to be > 0
      end

      expect(Set.new(filtered_transactions).to_a).to eq(filtered_transactions)
    end
  end
end
