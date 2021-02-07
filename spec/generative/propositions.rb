module Propositions
  def self.FilteredTransactionsRespectTags(transactions, possible_tags, test_app)
    transactions.all? do |transaction|
      transaction_tags = test_app.tag_index[transaction.id]

      return false if transaction_tags.nil?

      tags = transaction_tags.map(&:name)
      same_tags = tags & possible_tags

      same_tags.length > 0
    end
  end
end
