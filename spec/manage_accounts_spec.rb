require_relative '../personal_finance'

describe 'Creating Accounts' do
  subject { PersonalFinance::Application.new }

  let(:command) { subject.method(:create_account) }

  it do
    expect(command.call('Checking').name).to eq('Checking')
  end
end
