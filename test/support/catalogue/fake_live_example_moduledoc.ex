defmodule Surface.Catalogue.FakeLiveExampleModuleDocFalse do
  @moduledoc false

  use Surface.Catalogue.LiveExample,
    subject: Surface.FakeComponent,
    title: "A fake example"

  def render(assigns) do
    ~F"""
    The code
    """
  end
end
