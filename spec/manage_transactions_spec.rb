require_relative 'test_application'

describe 'Creating Transactions' do
  subject { test_application }

  let(:account) { subject.create_account('Checking') }

  let(:command) { subject.method(:create_transaction) }

  before do
    # TODO: Refactor so that all calls to create_transaction go through one method with defaults
    # "Signature shielding"
    command.call(name: 'T1', account_id: account.id, amount: 100.0, currency: :usd, day_of_month: 1)
  end

  it do
#    expect(subject.transactions.first.account).to eq(account)
    expect(subject.transactions.first.amount).to eq(100.0)
    expect(subject.transactions.first.name).to eq('T1')
  end
end