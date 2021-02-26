require_relative '../../view'

class LayoutView
  include View

  attr_reader :content

  def initialize(content)
    @content = content
  end

  def template
    File.read('use_cases/transactions/layout_view.erb')
  end
end