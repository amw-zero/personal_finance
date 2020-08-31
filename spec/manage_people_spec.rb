require_relative '../personal_finance'
require_relative 'datastore'

describe 'Creating People' do
  subject do
    PersonalFinance::Application.new(
      datastore: PersonalFinance::Datastore.create_null
    )
  end

  let(:command) { subject.method(:create_person) }

  before do
    command.call('Jane')
  end

  it do
    expect(subject.people.first.name).to eq('Jane')
  end
end