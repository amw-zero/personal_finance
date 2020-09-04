require 'dry-struct'
require 'bmg'
require 'pg'
require 'bmg/sequel'
require_relative 'postgres/postgres'
require 'pry'

module Types
  include Dry::Types()
end

module PersonalFinance
  class MemoryPersistence
    attr_reader :people

    def initialize
      @relations = {
        people: Bmg::Relation.new([]),
        incomes: Bmg::Relation.new([]),
        accounts: Bmg::Relation.new([])
      }
      @ids = {
        people: 1,
        incomes: 1,
        accounts: 1
      }
    end

    def relation
      @relations[:people]
    end

    def accounts
      @relations[:accounts]
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

  class Datastore
    def initialize(persistence: PostgresPersistence.new)
      @persistence = persistence
    end

    def persist(relation, data)
      @persistence.persist(relation, data)
    end

    def people
      @persistence.relation.map do |data|
        Person.new(data)
      end
    end

    def incomes(include: nil)
      @persistence.relation_of(:incomes).map do |data|
        data[:currency] = data[:currency].to_sym
        Income.new(data)
      end
    end

    def accounts
      @persistence.relation_of(:accounts).map do |data|
        Account.new(data)
      end
    end

    def cash_flow(account_id)
      incomes = @persistence.relation_of(:incomes)
      accounts = @persistence.relation_of(:accounts).restrict(id: account_id)
      incomes.join(accounts, { account_id: :id }).map do |data|
        data[:currency] = data[:currency].to_sym
        Income.new(data)
      end
    end
  end

  class Application
    attr_reader :accounts, :linked_accounts

    def initialize(datastore: Datastore.new)
      @accounts = []
      @linked_accounts = []
      @datastore = datastore
    end

    def create_person(name)
      Person.new(name: name).tap do |p|
        @datastore.persist(:people, p.attributes)
      end
    end

    def create_account(name)
      Account.new(name: name).tap do |a|
        @datastore.persist(:accounts, a.attributes)
      end
    end

    def link_account(person:, account:)
      LinkedAccount.new(person: person, account: account).tap do |la|
        @linked_accounts << la
      end
    end

    def create_income(account_id:, amount:, currency:, day_of_month:)
      Income.new(
        amount: amount, 
        currency: currency, 
        day_of_month: day_of_month
      ).tap do |i|
        @datastore.persist(:incomes, persistable_income(i, account_id))
      end
    end

    def people
      @datastore.people
    end

    def accounts
      @datastore.accounts
    end

    def incomes
      @datastore.incomes
    end

    def cash_flow(account_id)
      @datastore.cash_flow(account_id)
    end

    def persistable_income(i, account_id)
      i.attributes.merge({ currency: i.currency.to_s, account_id: account_id })
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

  class Income < Dry::Struct
    attribute? :id, Types::Integer
    attribute? :account, Account
    attribute :amount, Types::Float
    attribute :currency, Types::Value(:usd)
    attribute :day_of_month, Types::Integer
  end

  private_constant :Person
  private_constant :Account
  private_constant :LinkedAccount
end
