defmodule Surface.Catalogue.FakePlayground do
  use Surface.Catalogue.Example,
    subject: Surface.Components.Form,
    catalogue: Surface.Components.FakeCatalogue

  def render(assigns) do
    ~H"""
    The code
    """
  end
end
