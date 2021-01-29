# frozen_string_literal: true

require_relative 'test_application'

describe 'Tagging transactions' do
  subject { test_application }

  let(:checking_account) { subject.create_account('Checking') }
  let(:semi_monthly_income1) do
    subject.create_transaction(name: 'Income 1', account_id: checking_account.id, amount: 100.0, currency: :usd, day_of_month: 1)
  end
  let(:semi_monthly_income2) do
    subject.create_transaction(name: 'Income 2', account_id: checking_account.id, amount: 100.0, currency: :usd, day_of_month: 15)
  end
  let(:other_transaction) do
    subject.create_transaction(name: 'Expense', account_id: checking_account.id, amount: 200.0, currency: :usd, day_of_month: 11)
  end

  before do
    subject.tag_transaction(semi_monthly_income1.id, tag: 'income')
    subject.tag_transaction(semi_monthly_income2.id, tag: 'income')
  end

  let(:transactions) do
    subject.transactions_for_tags(['income'], subject.tag_index)
  end

  context 'when searching for the union of tags' do
    it 'returns transactions that have any of the specified tags' do
      expect(transactions.flat_map { |t| t[:transaction_set].transactions }.map(&:day_of_month)).to eq([1, 15])
    end
  end

  context 'when searching for the intersection of tags' do
    before do
      subject.tag_transaction(semi_monthly_income1.id, tag: 'second_tag')
    end

    let(:transactions) do
      subject.transactions_for_tags(
        %w[income second_tag],
        subject.tag_index,
        intersection: true
      )
    end

    it 'returns transactions that are tagged with all of the specified tags' do
      expect(
        transactions.flat_map { |t| t[:transaction_set].transactions }.map(&:day_of_month)
      ).to eq([1])
    end
  end

  describe 'tags for transaction' do
    it do
      expect(subject.tag_index.transform_values { |tag| tag.map(&:name) }).to eq({
                                                                                   semi_monthly_income1.id => ['income'],
                                                                                   semi_monthly_income2.id => ['income']
                                                                                 })
    end
  end
end
