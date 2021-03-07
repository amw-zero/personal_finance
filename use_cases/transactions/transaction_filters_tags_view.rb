# frozen_string_literal: true

require_relative '../../view'

class TransactionFiltersTagsView
  include View

  attr_reader :params, :tag_index, :accounts

  def initialize(params:, tag_index:, accounts:)
    @params = params
    @tag_index = tag_index
    @accounts = accounts
  end

  def template
    File.read('use_cases/transactions/transaction_filters_tags_view.erb')
  end
end
