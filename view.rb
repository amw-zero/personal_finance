class ErbRenderer
  def initialize(view)
    @view = view
  end

  def render
    rhtml = ERB.new(@view.template)
    rhtml.result(@view.get_binding)
  end
end