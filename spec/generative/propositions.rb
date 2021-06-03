# frozen_string_literal: true

module Propositions
  def self.FilteredTransactionsRespectTags(transactions, possible_tags, tag_index)
    transactions.all? do |transaction|
      transaction_tags = tag_index[transaction.id]

      return false if transaction_tags.nil?

      tags = transaction_tags.map(&:name)
      same_tags = tags & possible_tags

      !same_tags.empty?
    end
  end
end
