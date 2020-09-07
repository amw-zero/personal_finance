require_relative 'test_application'

describe 'Calculating sum of transaction amounts' do
  subject { test_application }

  let(:account) { subject.create_account('Checking') }
  let(:transaction1) { subject.create_transaction(name: 'T1', account_id: account.id, amount: 100.0, currency: :usd, day_of_month: 1) }
  let(:transaction2) { subject.create_transaction(name: 'T2', account_id: account.id, amount: 150.0, currency: :usd, day_of_month: 2) }

  before do
    subject.tag_transaction(transaction1.id, tag: 'tag')
    subject.tag_transaction(transaction2.id, tag: 'tag')
  end

  it do
    expect(subject.transactions_for_tags(['tag'], subject.tag_index).sum).to eq(250.0)
  end
end