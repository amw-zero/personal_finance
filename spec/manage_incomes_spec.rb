require_relative '../personal_finance'
require_relative 'datastore'

describe 'Creating Incomes' do
  subject do
    PersonalFinance::Application.new(
      datastore: PersonalFinance::Datastore.create_null
    )
  end

  let(:account) { subject.create_account('Checking') }

  let(:command) { subject.method(:create_income) }

  before do
    command.call(account_id: account.id, amount: 100.0, currency: :usd, day_of_month: 1)
  end

  it do
#    expect(subject.incomes.first.account).to eq(account)
    expect(subject.incomes.first.amount).to eq(100.0)
  end
end