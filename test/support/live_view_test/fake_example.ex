defmodule Surface.LiveViewTestTest.FakeExample do
  use Surface.Catalogue.Example,
    subject: Surface.LiveViewTestTest.FakeComponent,
    title: "A fake example",
    assert: "the code"

  def render(assigns), do: ~F[the code]
end
