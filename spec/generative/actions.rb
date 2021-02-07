require 'hypothesis'

module ApplicationActions
  CREATE_ACCOUNT = :create_account
  CREATE_TRANSACTION = :create_transaction
  CREATE_TAG = :create_tag
  CREATE_TAG_SET = :create_tag_set

  class Sequences
    include Hypothesis
    include Hypothesis::Possibilities

    def initialize(actions, fresh_application:)
      @actions = actions
      @application_block = fresh_application
    end

    def check!
      hypothesis(max_valid_test_cases: 1_000, phases: Phase.excluding(:shrink)) do
        test_app = application_block.call

        any(
          arrays(
            of: element_of(actions),
            min_size: 5,
            max_size: 100
          ),
          name: 'Actions'
        ).each do |action|
          _execute(action, in_app: test_app)
        end

        yield test_app
      end
    end

    private

    def _execute(action, in_app:)
      test_app = in_app

      case action
      when :create_account
        account_name = any strings, name: 'Account Name'
        test_app.create_account(account_name)
      when :create_transaction
        return if test_app.accounts.empty?

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
        return if test_app.all_transactions.transactions.empty?

        transaction = any(element_of(test_app.all_transactions.transactions))
        test_app.tag_transaction(transaction.id, tag: any(strings))
      when :create_tag_set
        # params = {
        #   transaction_tag: [String]
        # }
        # use_case = [String] -> [TransactionTag] -> ApplicationState
        # Would be good to have a domain constraint, i.e. "Strings are valid TransactionTags"

        tags = test_app.transaction_tags.map(&:name)
        return if tags.empty?

        bad_inputs = ['jkl', 'randM']
        tag_inputs = from(element_of(tags), element_of(bad_inputs))

        params = any(
          hashes_of_shape(
            title: strings,
            transaction_tag: arrays(of: tag_inputs)
          )
        )

        test_app.create_transaction_tag_set(params)
      end
    end

    attr_reader :actions, :application_block
  end
end