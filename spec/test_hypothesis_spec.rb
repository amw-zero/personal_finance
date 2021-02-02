# frozen_string_literal: true

require_relative 'test_application'
require 'hypothesis'

describe 'Hypothesis' do
  include Hypothesis
  include Hypothesis::Possibilities

  specify do
    x = 0
    hypothesis(max_valid_test_cases: 1_000) do
      puts;puts;
      puts "---- Start block ----"
      puts "Iteration: #{x}"
      x += 1

      test_app = test_application

      action = element_of([:create_account, :create_transaction, :create_tag])
      actions = any(arrays(of: action, min_size: 5, max_size: 100), name: 'Actions')

      actions.each do |a|
        puts "Performing: #{a}"

        case a
        when :create_account
          account_name = any strings, name: 'Account Name'
          test_app.create_account(account_name)
        when :create_transaction
          next if test_app.accounts.empty?
          account = any element_of(test_app.accounts), name: 'Transaction Account'
          amount = any integers(min: 1, max: 500), name: 'Transaction Amount'
          test_app.create_transaction(
            name: any(strings),
            account_id: account.id,
            amount: amount.to_f,
            currency: :usd,
            day_of_month: any(integers(min: 1, max: 31))
          )
        when :create_tag
          next if test_app.all_transactions.empty?

          transaction = any(element_of(test_app.all_transactions))
          test_app.tag_transaction(transaction.id, tag: any(strings))
        end
      end

      max_count = if test_app.transaction_tags.count == 0
          2
      else
        test_app.transaction_tags.count
      end
      tag_sample_count = any integers(min: 1, max: max_count)
      possible_tags = test_app.transaction_tags.sample(tag_sample_count).map(&:name)

      puts "Sampled #{tag_sample_count} tags: #{possible_tags}"

      filtered_transactions = test_app.use_cases[:transactions].transactions_for_tags(possible_tags, nil)
      puts "Got #{filtered_transactions.count} filtered transactions"

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
