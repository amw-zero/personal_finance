require_relative '../personal_finance'

describe 'Creating Accounts' do
  subject { PersonalFinance::Model.new }

  let(:command) { subject.method(:create_account) }

  it do
    expect(command.call('Checking').name).to eq('Checking')
  end
end