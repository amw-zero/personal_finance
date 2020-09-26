# frozen_string_literal: true

require 'dry-struct'
require 'bmg'
require 'pg'
require 'bmg/sequel'
require_relative 'postgres/postgres'

# Bring Dry::Struct types into scope
module Types
  include Dry::Types()
end

# The top-level module for the Personal Finance app
module PersonalFinance
  # Store relations in memory
  class MemoryPersistence
    attr_reader :people

    def initialize
      @relations = Hash.new(Bmg::Relation.new([]))
      @ids = Hash.new(1)
    end

    def relation_of(rel_name)
      @relations[rel_name]
    end

    def persist(relation, data)
      data[:id] = @ids[relation]
      @ids[relation] += 1
      @relations[relation] = @relations[relation].union(Bmg::Relation.new([data]))
    end
  end

  # Store relations in postgres
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

    def relation_of(rel_name)
      Bmg.sequel(rel_name, @db)
    end
  end

  # The top-level Personal Finance application
  class Application
    attr_reader :endpoints

    def initialize(persistence: PostgresPersistence.new)
      @accounts = []
      @linked_accounts = []
      @persistence = persistence
      @endpoints = {
        tag_sets_post: { path: '/transaction_tag_sets', action: ->(params) { create_transaction_tag_set(params) } }
      }
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

    def create_transaction_tag_set(params)
      title = params[:title]
      tags = params[:transaction_tag]
      TransactionTagSet.new(title: title, tags: tags).tap do |t|
        t.attributes[:tags] = t.attributes[:tags].join(',')
        @persistence.persist(:transaction_tag_sets, t.attributes)
      end
    end

    def people
      to_models(
        relation(:people),
        Person
      )
    end

    def accounts
      to_models(
        relation(:accounts),
        Account
      )
    end

    def transactions
      to_models(
        relation(:transactions),
        Transaction
      ).sort_by(&:day_of_month)
    end

    def cash_flow(account_id)
      transactions = relation(:transactions)
      accounts = relation(:accounts).restrict(id: account_id)
      to_models(
        transactions.join(accounts, { account_id: :id }),
        Transaction
      ).sort_by(&:day_of_month)
    end

    def transactions_for_tags(tags, tag_index, intersection: false)
      transaction_relation = if intersection
                               transaction_ids = tag_index.select do |_, t|
                                 (t.map(&:name) & tags).count == tags.count
                               end.keys
                               relation(:transactions).restrict(id: transaction_ids)
                             else
                               _transaction_for_tags(tags)
                             end

      transactions = to_models(transaction_relation, Transaction)

      [{ title: 'Current Tag', tags: tags, transaction_set: TransactionSet.new(transactions: transactions) }]
    end

    def _transaction_for_tags(tags)
      transactions = relation(:transactions)
      tags = relation(:transaction_tags).restrict(name: tags).rename(name: :tag_name)
      tags.join(transactions.rename(id: :transaction_id), [:transaction_id])
    end

    def transactions_for_tag_sets(tag_set_ids)
      tag_sets = to_models(
        relation(:transaction_tag_sets).restrict(id: tag_set_ids),
        TransactionTagSet
      )

      tag_sets.map do |tag_set|
        {
          title: tag_set.title,
          tags: tag_set.tags,
          transaction_set: TransactionSet.new(
            transactions: to_models(_transaction_for_tags(tag_set.tags), Transaction)
          )
        }
      end
    end

    def tag_index
      to_models(
        relation(:transaction_tags),
        TransactionTag
      ).group_by(&:transaction_id)
    end

    def transaction_tags
      relation(:transaction_tags).map do |data|
        TransactionTag.new(data)
      end.uniq(&:name)
    end

    def transaction_tag_sets(ids)
      to_models(relation(:transaction_tag_sets).restrict(id: ids), TransactionTagSet)
    end

    def all_transaction_tag_sets
      to_models(relation(:transaction_tag_sets), TransactionTagSet)
    end

    private

    def relation(name)
      @persistence.relation_of(name)
    end

    def persistable_transation(transaction)
      # TODO: the attributes are mutable here, and this is surprising and confusing
      # Persisting this later one modifies the attributes which modifies the struct.
      # Terrifying.
      transaction.attributes.merge!({ currency: transaction.currency.to_s })
    end

    def to_models(relation, model_klass)
      puts relation.to_sql if relation.is_a?(Bmg::Sql::Relation)
      case model_klass.to_s
      when 'PersonalFinance::Transaction'
        relation.map do |data|
          data[:currency] = data[:currency].to_sym
          model_klass.new(data)
        end
      when 'PersonalFinance::TransactionTagSet'
        relation.map do |data|
          data[:tags] = data[:tags].split(',')
          model_klass.new(data)
        end
      else
        relation.map do |data|
          model_klass.new(data)
        end
      end
    end
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

  # A financial transaction, e.g. an expense or an income
  class Transaction < Dry::Struct
    attribute? :id, Types::Integer
    attribute? :account, Account
    attribute :account_id, Types::Integer
    attribute :amount, Types::Float
    attribute :name, Types::String
    attribute :currency, Types::Value(:usd)
    attribute :day_of_month, Types::Integer
  end

  # A categorization of a transaction, e.g. "debt" or "house"
  class TransactionTag < Dry::Struct
    attribute? :id, Types::Integer
    attribute :transaction_id, Types::Integer
    attribute :name, Types::String
  end

  # A set of transactions
  class TransactionSet < Dry::Struct
    attribute :transactions, Types::Array(Transaction)

    def sum
      transactions.map(&:amount).sum.round(2)
    end
  end

  # A set of transaction tags
  class TransactionTagSet < Dry::Struct
    attribute? :id, Types::Integer
    attribute :title, Types::String
    attribute :tags, Types::Array(Types::String)
  end

  private_constant :Person
  private_constant :Account
  private_constant :LinkedAccount
  private_constant :Transaction
  private_constant :TransactionTag
  private_constant :TransactionTagSet
end
