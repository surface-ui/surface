defmodule <%= inspect(web_module) %>.Components.Hero.Playground do
  use Surface.Catalogue.Playground,
    subject: <%= inspect(web_module) %>.Components.Hero,
    height: "250px",
    body: [style: "padding: 1.5rem;"]

  data props, :map, default: %{
    subtitle: "Welcome to Surface!",
    color: "info"
  }

  def render(assigns) do
    ~F"""
    <Hero {...@props} />
    """
  end
end
