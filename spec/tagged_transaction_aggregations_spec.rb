# frozen_string_literal: true

require_relative 'test_application'

describe 'Calculating sum of transaction amounts' do
  subject { test_application }

  let(:account) { subject.create_account('Checking') }
  let(:transaction1) do
    subject.create_transaction(name: 'T1', account_id: account.id, amount: 100.0, currency: :usd,
                               recurrence_rule: 'FREQ=MONTHLY')
  end
  let(:transaction2) do
    subject.create_transaction(name: 'T2', account_id: account.id, amount: 150.0, currency: :usd,
                               recurrence_rule: 'FREQ=MONTHLY')
  end

  before do
    subject.tag_transaction(transaction1.id, tag: 'tag')
    subject.tag_transaction(transaction2.id, tag: 'tag')
  end

  let(:transactions) do
    subject.transactions({ transaction_tag: ['tag'] })[:transactions]
  end

  it do
    expect(transactions.sum).to eq(250.0)
  end
end
