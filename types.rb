# frozen_string_literal: true

# Bring Dry::Struct types into scope
module Types
  include Dry::Types()
end

# A person
class Person < Dry::Struct
  attribute? :id, Types::Integer
  attribute :name, Types::String
end

# A finance account
class Account < Dry::Struct
  attribute? :id, Types::Integer
  attribute :name, Types::String
end

# A relationship between a Person and an Account
class LinkedAccount < Dry::Struct
  attribute :person, Person
  attribute :account, Account
end

# A financial transaction, e.g. an expense or an income. "Planned" because it
# is not an actual transaction between accounts, but rather can have an associated
# recurrence rule which represents a conceptual infinite set of Transactions.
class PlannedTransaction < Dry::Struct
  attribute? :id, Types::Integer
  attribute? :account, Account
  attribute :account_id, Types::Integer
  attribute :amount, Types::Float
  attribute :name, Types::String
  attribute :currency, Types::Value(:usd)
  attribute :recurrence_rule, Types::String
  attribute :occurs_on, Types.Constructor(Date) { |occurs_on| occurs_on }

  def occurrences_within(period)
    start_date = period.begin.to_time

    RRule.parse(recurrence_rule, dtstart: occurs_on.to_time, tzid: Time.now.getlocal.zone).between(
      start_date,
      period.end.to_time
    )
  end

  def income?
    amount.positive?
  end
end

# A "concrete" transaction, i.e. one that occurs on a specific date. Since
# PlannedTransactions are defined with recurrence rules that specify when they actually occur,
# Transaction is one instance of the recurrence rule.
class Transaction < Dry::Struct
  extend Forwardable
  def_delegators :planned_transaction, :name, :amount, :income?

  attribute :date, Types.Constructor(Date) { |date| date }
  attribute :planned_transaction, PlannedTransaction
end

# A categorization of a transaction, e.g. "debt" or "house"
class TransactionTag < Dry::Struct
  attribute? :id, Types::Integer
  attribute :transaction_id, Types::Integer
  attribute :name, Types::String
end

# A set of transactions
# TODO: Rename or at least alias to Budget
# There might be a use case for sets of Transactions that aren't
# semantically budgets
class TransactionSet < Dry::Struct
  attribute :transactions, Types::Array(PlannedTransaction) | Types::Array(Transaction)

  def sum
    transactions.map(&:amount).sum.round(2)
  end
end

class PayPeriod < Dry::Struct
  attribute :incomes, TransactionSet
  attribute :transactions, TransactionSet
  attribute :date_range, Types.Instance(Range)
end

class Period < Dry::Struct
  attribute :transactions, TransactionSet
  attribute :date_range, Types.Instance(Range)
end

# A set of transaction tags
class TransactionTagSet < Dry::Struct
  attribute? :id, Types::Integer
  attribute :title, Types::String
  attribute :tags, Types::Array(Types::String)
end
