# frozen_string_literal: true

require_relative '../../view'

class LayoutView
  include View

  attr_reader :content, :interactions

  def initialize(content, interactions:)
    @content = content
    @interactions = interactions
  end

  def template
    File.read('use_cases/transactions/layout_view.erb')
  end
end
