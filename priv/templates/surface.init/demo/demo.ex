defmodule <%= inspect(web_module) %>.Demo do
  use Surface.LiveView

  alias <%= inspect(web_module) %>.Components.Hero

  def render(assigns) do
    ~F"""
    <div>
      <Hero name="John Doe" subtitle="How are you?" color="info"/>
    </div>
    """
  end
end
