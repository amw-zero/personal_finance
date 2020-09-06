require_relative 'test_application'

describe 'Tagging transactions' do
  subject { test_application }

  let(:checking_account) { subject.create_account('Checking') }
  let(:semi_monthly_income1) do
    subject.create_transaction(account_id: checking_account.id, amount: 100.0, currency: :usd, day_of_month: 1)
  end
  let(:semi_monthly_income2) do
    subject.create_transaction(account_id: checking_account.id, amount: 100.0, currency: :usd, day_of_month: 15)
  end
  let(:other_transaction) do
    subject.create_transaction(account_id: checking_account.id, amount: 200.0, currency: :usd, day_of_month: 11)
  end

  before do
    subject.tag_transaction(semi_monthly_income1.id, tag: 'income')
    subject.tag_transaction(semi_monthly_income2.id, tag: 'income')
  end

  it do
    expect(subject.transactions_for_tag('income').map(&:day_of_month)).to eq([1, 15])
  end

  describe 'tags for transaction' do
    it do 
      expect(subject.tag_index.transform_values { |tag| tag.map(&:name) }).to eq({
        semi_monthly_income1.id => ['income'],
        semi_monthly_income2.id => ['income'] 
      })
    end
  end
end