# frozen_string_literal: true

require 'simplecov'

SimpleCov.start

require_relative '../personal_finance'
require_relative '../memory_persistence'

def test_application
  PersonalFinance::Application.new(
    persistence: MemoryPersistence.new
  )
end
