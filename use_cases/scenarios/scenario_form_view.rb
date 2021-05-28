# frozen_string_literal: true

require_relative '../../view'
require 'ostruct'

class ScenarioFormView
  include View

  attr_reader :interactions, :scenarios

  None = OpenStruct.new(id: 'none', name: 'none')

  def initialize(interactions:, scenarios:)
    @interactions = interactions
    scenarios = scenarios.dup
    scenarios.insert(0, None)
    @scenarios = scenarios
  end

  def template
    File.read('use_cases/scenarios/scenario_form_view.erb')
  end
end