require 'dry-struct'

module Types
  include Dry::Types()
end

module PersonalFinance
  class Model
    def create_person(name)
      Person.new(name: name)
    end

    def create_account(name)
      Account.new(name: name)
    end

    def link_account(person:, account:)
      LinkedAccount.new(person: person, account: account)
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
