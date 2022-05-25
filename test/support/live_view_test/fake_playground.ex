defmodule Surface.LiveViewTestTest.FakePlayground do
  use Surface.Catalogue.Playground,
    subject: Surface.LiveViewTestTest.FakeComponent,
    catalogue: Surface.Components.FakeCatalogue

  data props, :map, default: %{}

  def render(assigns), do: ~F[]
end
