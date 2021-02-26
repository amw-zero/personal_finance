class TransactionTableHeaderView
  attr_reader :title
  
  def initialize(title:)
    @title = title
  end

  def get_binding
    binding
  end

  def template
    File.read('use_cases/transactions/transaction_table_header_view.erb')
  end
end