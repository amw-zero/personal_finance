require_relative '../personal_finance'

describe 'Creating Accounts' do
  subject { PersonalFinance::Application.new }

  let(:command) { subject.method(:create_account) }

  before do
    command.call('Checking')
  end

  it do
    expect(subject.accounts.first.name).to eq('Checking')
  end
end
