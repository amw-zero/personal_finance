require 'hypothesis'

module ApplicationActions 
  CREATE_ACCOUNT = :create_account
  CREATE_TRANSACTION = :create_transaction
  CREATE_TAG = :create_tag

  def self.handle(action, in_app:)
    include Hypothesis
    include Hypothesis::Possibilities

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
    end
  end
end