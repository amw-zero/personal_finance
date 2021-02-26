class TransactionFiltersTagSetsView
  attr_reader :params, :tag_sets
  
  def initialize(params:, tag_sets:)
    @params = params
    @tag_sets = tag_sets
  end

  def get_binding
    binding
  end

  def template
    File.read('transaction_filters_tag_sets_view.erb')
  end
end