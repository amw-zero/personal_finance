class CreateTransactionView
  attr_reader :create_transaction_interaction

  def initialize(create_transaction_interaction)
    @create_transaction_interaction = create_transaction_interaction
  end

  def get_binding
    binding
  end

  def template
    File.read('./create_transaction_view.rb')
  end      
end