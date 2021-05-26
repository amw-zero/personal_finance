# frozen_string_literal: true

require_relative '../../view'

class ScenarioFormView
  include View

  attr_reader :interactions

  def initialize(interactions:)
    @interactions = interactions
  end

  def template
    File.read('use_cases/scenarios/scenario_form_view.erb')
  end
end