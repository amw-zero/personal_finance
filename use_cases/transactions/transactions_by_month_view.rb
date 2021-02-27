# frozen_string_literal: true

class TransactionsByMonthView
  attr_reader :periods

  def initialize(periods:)
    @periods
  end

  def get_binding
    binding
  end

  def template
    File.read('use_cases/transactions/transactions_by_month_view.erb')
  end
end
