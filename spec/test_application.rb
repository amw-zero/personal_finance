# frozen_string_literal: true

require 'simplecov'
require 'delegate'

SimpleCov.start

require_relative '../personal_finance'
require_relative '../memory_persistence'
require_relative '../view'

class TestApplication < SimpleDelegator
  def execute_and_render(interaction, params={})
    result = execute(interaction, params)

    if result.is_a?(Hash)
      execute_and_render(result, {})
    else
      ErbRenderer.new(result).render
    end

    result
  end
end

def test_application
  TestApplication.new(
    PersonalFinance::Application.new(
      persistence: MemoryPersistence.new
    )
  )
end
