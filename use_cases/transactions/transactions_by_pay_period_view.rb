# frozen_string_literal: true

class TransactionsByPayPeriodView
  attr_reader :pay_periods

  def initialize(pay_periods:)
    @pay_periods = pay_periods
  end

  def get_binding
    binding
  end

  def template
    File.read('use_cases/transactions/transactions_by_pay_period_view.erb')
  end
end
