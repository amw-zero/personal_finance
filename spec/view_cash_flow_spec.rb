# frozen_string_literal: true

require_relative 'test_application'

xdescribe 'Viewing cash flow' do
  subject { test_application }

  let(:checking_account) { subject.create_account('Checking') }
  let(:savings_account) { subject.create_account('Savings') }

  before do
    subject.create_transaction(name: 'T1', account_id: checking_account.id, amount: 100.0, currency: :usd,
                               recurrence_rule: 'FREQ=MONTHLY')
    subject.create_transaction(name: 'T2', account_id: checking_account.id, amount: 200.0, currency: :usd,
                               recurrence_rule: 'FREQ=MONTHLY')
    subject.create_transaction(name: 'T3', account_id: savings_account.id, amount: 200.0, currency: :usd,
                               recurrence_rule: 'FREQ=MONTHLY')
  end

  it do
    expect(subject.cash_flow(checking_account.id).map(&:amount)).to eq([100, 200])
  end
end
