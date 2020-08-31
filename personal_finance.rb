require 'dry-struct'

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

  class Datastore
    def initialize(persistence: MemoryPersistence.new)
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
