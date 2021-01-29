# frozen_string_literal: true

require_relative 'test_application'

describe 'Creating People' do
  subject { test_application }

  let(:command) { subject.method(:create_person) }

  before do
    command.call('Jane')
  end

  it do
    expect(subject.people.first.name).to eq('Jane')
  end
end
