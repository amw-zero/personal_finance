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
  end

  class Person < Dry::Struct::Value
    attribute :name, Types::String
  end

  class Account < Dry::Struct::Value
    attribute :name, Types::String
  end

  private_constant :Person
end
