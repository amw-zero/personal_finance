require_relative 'test_application'


describe 'Viewing cash flow' do
  subject { test_application }

  let(:checking_account) { subject.create_account('Checking') }
  let(:savings_account) { subject.create_account('Savings') }

  before do
    subject.create_income(account_id: checking_account.id, amount: 100.0, currency: :usd, day_of_month: 1)
    subject.create_income(account_id: checking_account.id, amount: 200.0, currency: :usd, day_of_month: 1)
    subject.create_income(account_id: savings_account.id, amount: 200.0, currency: :usd, day_of_month: 1)
  end

  it do
    expect(subject.cash_flow(checking_account.id).map(&:amount)).to eq([100, 200])
  end
end