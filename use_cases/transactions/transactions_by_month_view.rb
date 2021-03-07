# frozen_string_literal: true

require_relative '../../view'

class TransactionsByMonthView
  include View

  attr_reader :periods

  def initialize(periods:)
    @periods = periods
  end

  def template
    File.read('use_cases/transactions/transactions_by_month_view.erb')
  end
end
