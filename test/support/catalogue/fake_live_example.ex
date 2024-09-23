defmodule Surface.Catalogue.FakeLiveExample do
  use Surface.Catalogue.LiveExample,
    subject: Surface.FakeComponent,
    title: "A fake example",
    assert: ["The code"]

  def render(assigns) do
    ~F"""
    The code
    """
  end
end
