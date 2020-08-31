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
      @people = []
    end

    def persist(data)
      @people << data
    end
  end

  class PostgresPersistence
    def initialize
      @db = Sequel.connect(Postgres::SERVER_URL)
    end

    def persist(data)
      relation = Bmg.sequel(:people, @db)
      relation.insert(data.attributes)
    end

    def people
      relation = Bmg.sequel(:people, @db)
      relation.restrict(Predicate.neq(name: 'abc')).map do |data|
        Person.new(data)
      end
    end
  end

  class Datastore
    def initialize(persistence: PostgresPersistence.new)
      @persistence = persistence
    end

    def persist(data)
      @persistence.persist(data)
    end

    def people
      @persistence.people
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
        @datastore.persist(p)
      end
    end

    def create_account(name)
      Account.new(name: name).tap do |a|
        @accounts << a
      end
    end

    def link_account(person:, account:)
      LinkedAccount.new(person: person, account: account).tap do |la|
        @linked_accounts << la
      end
    end

    def people
      @datastore.people
    end
  end

  class Person < Dry::Struct
    attribute? :id, Types::Integer
    attribute :name, Types::String
  end

  class Account < Dry::Struct
    attribute :name, Types::String
  end

  class LinkedAccount < Dry::Struct
    attribute :person, Person
    attribute :account, Account
  end

  private_constant :Person
  private_constant :Account
  private_constant :LinkedAccount
end
