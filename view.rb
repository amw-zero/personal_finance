class ErbRenderer
  def initialize(view)
    @view = view
  end

  def render
    rhtml = ERB.new(@view.template)
    rhtml.run(@view.get_binding)
  end
end