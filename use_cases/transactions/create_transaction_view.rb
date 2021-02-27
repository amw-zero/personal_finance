class CreateTransactionView
  attr_reader :create_transaction_interaction

  def initialize(create_transaction_interaction, accounts:)
    @create_transaction_interaction = create_transaction_interaction
    @accounts = accounts
  end

  def get_binding
    binding
  end

  def template
    File.read('use_cases/transactions/create_transaction_view.erb')
  end      
end