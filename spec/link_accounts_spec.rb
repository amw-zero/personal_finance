require_relative '../personal_finance'

describe 'Linking Accounts' do
  subject do
    PersonalFinance::Application.new(
      datastore: PersonalFinance::Datastore.create_null
    )
  end

  let(:command) { subject.method(:link_account) }
  let(:person) { subject.create_person('Test Person') }
  let(:account) { subject.create_account('Checking') }

  before do
    subject.link_account(person: person, account: account)
  end

  let(:linked_account) { subject.linked_accounts.first }

  it do
    expect(linked_account.person).to eq(person)
    expect(linked_account.account).to eq(account)
  end
end
