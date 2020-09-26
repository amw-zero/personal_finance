describe 'Saving TransactionTagSets' do
  subject { test_application }

  let(:checking_account) { subject.create_account('Checking') }
  let(:semi_monthly_income1) do
    subject.create_transaction(name: 'Income 1', account_id: checking_account.id, amount: 100.0, currency: :usd, day_of_month: 1)
  end
  let(:semi_monthly_income2) do
    subject.create_transaction(name: 'Income 2', account_id: checking_account.id, amount: 100.0, currency: :usd, day_of_month: 15)
  end
  let(:other_transaction) do
    subject.create_transaction(name: 'Expense', account_id: checking_account.id, amount: 200.0, currency: :usd, day_of_month: 11)
  end
  let(:tag_set) { subject.create_transaction_tag_set({ title: 'Income + Special', transaction_tag: ['income', 'special'] }) }

  before do
    subject.tag_transaction(semi_monthly_income1.id, tag: 'income')
    subject.tag_transaction(semi_monthly_income1.id, tag: 'special')
    subject.tag_transaction(semi_monthly_income2.id, tag: 'income')
  end
trans
  context 'when querying transaction tags' do
    let(:tags_in_set) { subject.transaction_tag_set(tag_set.id).tags }

    it 'returns them' do
      expect(tags_in_set).to eq(['income', 'special'])
    end
  end
end
