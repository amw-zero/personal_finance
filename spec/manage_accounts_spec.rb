# frozen_string_literal: true

require_relative 'test_application'

describe 'Creating Accounts' do
  subject { test_application }

  let(:command) { subject.method(:create_account) }

  before do
    command.call('Checking')
  end

  it do
    expect(subject.accounts.first.name).to eq('Checking')
  end
end
