defmodule Surface.LiveViewTestTest.FakePlayground do
  use Surface.Catalogue.Playground,
    subject: Surface.LiveViewTestTest.FakeComponent,
    catalogue: Surface.Components.FakeCatalogue

  def render(assigns), do: ~F[]
end
