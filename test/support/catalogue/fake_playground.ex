defmodule Surface.Catalogue.FakePlayground do
  use Surface.Catalogue.Playground,
    subject: Surface.Components.FakeButton,
    catalogue: Surface.Components.FakeCatalogue

  @props [
    label: "My label",
    map: %{info: "info"}
  ]

  def render(assigns) do
    ~F"""
    {#for {prop, value} <- @props}
      {prop}: {inspect(value)}
    {/for}
    """
  end
end
