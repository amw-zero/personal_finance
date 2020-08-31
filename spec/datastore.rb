module PersonalFinance
  class Datastore
    def self.create_null
      Datastore.new(persistence: MemoryPersistence.new)
    end
  end
end