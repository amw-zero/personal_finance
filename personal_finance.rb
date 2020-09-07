require 'dry-struct'
require 'bmg'
require 'pg'
require 'bmg/sequel'
require_relative 'postgres/postgres'

module Types
  include Dry::Types()
end

module PersonalFinance
  class MemoryPersistence
    attr_reader :people

    def initialize
      @relations = Hash.new(Bmg::Relation.new([]))
      @ids = Hash.new(1)
    end

    def relation_of(r)
      @relations[r]
    end

    def persist(relation, data)
      data[:id] = @ids[relation]
      @ids[relation] += 1
      @relations[relation] = @relations[relation].union(Bmg::Relation.new([data]))
    end
  end

  class PostgresPersistence
    def initialize
      @db = Sequel.connect(Postgres::SERVER_URL)
    end

    def relation
      Bmg.sequel(:people, @db)
    end

    def persist(relation, data)
      relation = Bmg.sequel(relation, @db)
      relation.insert(data)
    end

    def relation_of(r)
      Bmg.sequel(r, @db)
    end
  end

  class Application
    attr_reader :accounts, :linked_accounts

    def initialize(persistence: PostgresPersistence.new)
      @accounts = []
      @linked_accounts = []
      @persistence = persistence
    end

    def create_person(name)
      Person.new(name: name).tap do |p|
        @persistence.persist(:people, p.attributes)
      end
    end

    def create_account(name)
      Account.new(name: name).tap do |a|
        @persistence.persist(:accounts, a.attributes)
      end
    end

    def link_account(person:, account:)
      LinkedAccount.new(person: person, account: account).tap do |la|
        @linked_accounts << la
      end
    end

    def create_transaction(name:, account_id:, amount:, currency:, day_of_month:)
      Transaction.new(
        name: name,
        account_id: account_id,
        amount: amount, 
        currency: currency, 
        day_of_month: day_of_month
      ).tap do |i|
        @persistence.persist(:transactions, persistable_transation(i))
      end
    end

    def tag_transaction(transaction_id, tag:)
      TransactionTag.new(
        transaction_id: transaction_id,
        name: tag
      ).tap do |i|
        @persistence.persist(:transaction_tags, i.attributes)
      end
    end

    def people
      @persistence.relation_of(:people).map do |data|
        Person.new(data)
      end
    end

    def accounts
      @persistence.relation_of(:accounts).map do |data|
        Account.new(data)
      end
    end

    def transactions
      @persistence.relation_of(:transactions).map do |data|
        data[:currency] = data[:currency].to_sym
        Transaction.new(data)
      end.sort_by(&:day_of_month)
    end

    def cash_flow(account_id)
      transactions = @persistence.relation_of(:transactions)
      accounts = @persistence.relation_of(:accounts).restrict(id: account_id)
      transactions.join(accounts, { account_id: :id }).map do |data|
        data[:currency] = data[:currency].to_sym
        Transaction.new(data)
      end.sort_by(&:day_of_month)
    end

    def transactions_for_tag(tag)
      transactions = relation(:transactions)
      tags = relation(:transaction_tags)
      transactions = to_models(
        tags.restrict(name: tag).join(transactions, { transaction_id: :id }),
        Transaction
      )
      TransactionSet.new(transactions: transactions)
    end

    def tag_index
      to_models(
        relation(:transaction_tags),
        TransactionTag
      ).group_by { |t| t.transaction_id }
    end

    def transaction_tags
      relation(:transaction_tags).map do |data|
        TransactionTag.new(data)
      end.uniq(&:name)
    end

    def relation(r)
      @persistence.relation_of(r)
    end

    def persistable_transation(t)
      # TODO: the attributes are mutable here, and this is surprising and confusing
      # Persisting this later one modifies the attributes which modifies the struct.
      # Terrifying.
      t.attributes.merge!({ currency: t.currency.to_s })
    end

    def to_models(relation, model_klass)
      case model_klass.to_s
      when 'PersonalFinance::Transaction'
        relation.map do |data|
          data[:currency] = data[:currency].to_sym
          model_klass.new(data)
        end
      else
        relation.map do |data|
          model_klass.new(data)
        end
      end
    end
  end

  class Person < Dry::Struct
    attribute? :id, Types::Integer
    attribute :name, Types::String
  end

  class Account < Dry::Struct
    attribute? :id, Types::Integer
    attribute :name, Types::String
  end

  class LinkedAccount < Dry::Struct
    attribute :person, Person
    attribute :account, Account
  end

  class Transaction < Dry::Struct
    attribute? :id, Types::Integer
    attribute? :account, Account
    attribute :account_id, Types::Integer
    attribute :amount, Types::Float
    attribute :name, Types::String
    attribute :currency, Types::Value(:usd)
    attribute :day_of_month, Types::Integer
  end

  class TransactionTag < Dry::Struct
    attribute? :id, Types::Integer
    attribute :transaction_id, Types::Integer
    attribute :name, Types::String
  end

  class TransactionSet < Dry::Struct
    attribute :transactions, Types::Array(Transaction)

    def sum
      transactions.map(&:amount).sum.round(2)
    end
  end

  private_constant :Person
  private_constant :Account
  private_constant :LinkedAccount
  private_constant :Transaction
  private_constant :TransactionTag
end
