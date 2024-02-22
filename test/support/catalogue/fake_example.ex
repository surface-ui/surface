defmodule Surface.Catalogue.FakeExample do
  use Surface.Catalogue.Example,
    subject: Surface.FakeComponent,
    title: "A fake example",
    assert: ["The code"]

  def render(assigns) do
    ~F"""
    The code
    """
  end
end
