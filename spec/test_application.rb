require_relative '../personal_finance'

def test_application
  PersonalFinance::Application.new(
    persistence: PersonalFinance::MemoryPersistence.new
  )
end