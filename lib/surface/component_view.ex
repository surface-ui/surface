defmodule Surface.ComponentView do
  use Phoenix.HTML

  def render(conn, component, props) do
    conn
    |> Phoenix.Controller.put_view(Surface.ComponentView)
    |> Phoenix.Controller.render("fake.html", Map.put(props, :__component, component))
  end

  def render(_template, assigns) do
    component = assigns[:__component]
    ~E"""
      <%= component.render(assigns, []) %>
    """
  end
end
