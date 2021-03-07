# frozen_string_literal: true

require_relative '../../view'

class TransactionsByPayPeriodView
  include View

  attr_reader :pay_periods

  def initialize(pay_periods:)
    @pay_periods = pay_periods
  end

  def template
    File.read('use_cases/transactions/transactions_by_pay_period_view.erb')
  end
end
