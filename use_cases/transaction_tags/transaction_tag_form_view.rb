# frozen_string_literal: true

require_relative '../../view'

class TransactionTagFormView
  include View

  attr_reader :transaction, :interactions

  def initialize(transaction:, interactions:)
    @transaction = transaction
    @interactions = interactions
  end

  def template
    File.read('use_cases/transaction_tags/transaction_tag_form_view.erb')
  end
end
