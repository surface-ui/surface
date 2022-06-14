defmodule Surface.Catalogue.FakePlayground do
  use Surface.Catalogue.Playground,
    subject: Surface.Components.FakeButton,
    catalogue: Surface.Components.FakeCatalogue

  @props [
    label: "My label"
  ]

  def render(assigns) do
    ~F"""
    {#for {prop, value} <- @props}
      {prop}: {value}
    {/for}
    """
  end
end
