require_relative '../personal_finance'
require_relative 'datastore'

def test_application
  PersonalFinance::Application.new(
    persistence: PersonalFinance::MemoryPersistence.new
  )
end