defmodule Surface.LiveViewTestTest.FakeLiveExample do
  use Surface.Catalogue.LiveExample,
    subject: Surface.LiveViewTestTest.FakeComponent,
    title: "A fake example",
    assert: "the code"

  def render(assigns), do: ~F[the code]
end
