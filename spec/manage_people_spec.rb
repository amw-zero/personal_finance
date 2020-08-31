require_relative '../personal_finance'

describe 'Creating People' do
  subject { PersonalFinance::Application.new }

  let(:command) { subject.method(:create_person) }

  before do
    command.call('Jane')
  end

  it do
    expect(subject.all_people.first.name).to eq('Jane')
  end
end