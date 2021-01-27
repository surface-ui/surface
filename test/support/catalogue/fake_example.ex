defmodule Surface.Catalogue.FakeExample do
  use Surface.Catalogue.Example,
    subject: Surface.Components.Form,
    title: "A fake example"

  def render(assigns) do
    ~H"""
    The code
    """
  end
end
