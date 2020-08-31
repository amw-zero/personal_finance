require_relative '../personal_finance'

describe 'Creating People' do
  subject { PersonalFinance::Application.new }

  let(:command) { subject.method(:create_person) }

  it do
    expect(command.call('Jane').name).to eq('Jane')
  end
end