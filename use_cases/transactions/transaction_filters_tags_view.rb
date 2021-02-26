require_relative '../../view'

class TransactionFiltersTagsView
  attr_reader :params, :tag_index, :accounts

  def initialize(params:, tag_index:, accounts:)    
    @params = params
    @tag_index = tag_index
    @accounts = accounts
  end

  def get_binding
    binding
  end

  def template
    File.read('use_cases/transactions/transaction_filters_tags_view.erb')
  end
end