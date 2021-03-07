# frozen_string_literal: true

require_relative 'test_application'

describe 'Creating Transactions' do
  subject { test_application }

  let(:account) { subject.create_account('Checking') }

  let(:command) { subject.method(:create_transaction) }

  before do
    # TODO: Refactor so that all calls to create_transaction go through one method with defaults
    # "Signature shielding"
    command.call(name: 'T1', account_id: account.id, amount: 100.0, currency: :usd, recurrence_rule: 'placeholder')
  end

  it do
    expect(subject.all_transactions[:transactions].transactions.first.account_id).to eq(account.id)
    expect(subject.all_transactions[:transactions].transactions.first.amount).to eq(100.0)
    expect(subject.all_transactions[:transactions].transactions.first.name).to eq('T1')
  end
end

describe 'Retrieving Transactions' do
  subject { test_application }

  let(:account) { subject.create_account('Checking') }

  before do
    subject.create_transaction(name: 'T1', account_id: account.id, amount: 100.0, currency: :usd,
                               recurrence_rule: 'placeholder')
    subject.create_transaction(name: 'T2', account_id: account.id, amount: 100.0, currency: :usd,
                               recurrence_rule: 'placeholder')
  end

  it 'returns the transactions ordered by their name' do
    expect(subject.all_transactions[:transactions].transactions.map(&:name)).to eq(%w[T1 T2])
  end
end
