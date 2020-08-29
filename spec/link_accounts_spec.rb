require_relative '../personal_finance'

describe 'Linking Accounts' do
  subject { PersonalFinance::Model.new }

  let(:command) { subject.method(:link_account) }
  let(:person) { subject.create_person('Test Person') }
  let(:account) { subject.create_account('Checking') }
  let(:linked_account) { subject.link_account(person: person, account: account) }

  it do
    expect(linked_account.person).to eq(person)
    expect(linked_account.account).to eq(account)
  end
end
