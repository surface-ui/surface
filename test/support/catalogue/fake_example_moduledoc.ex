defmodule Surface.Catalogue.FakeExampleModuleDocFalse do
  @moduledoc false

  use Surface.Catalogue.Example,
    subject: Surface.FakeComponent,
    title: "A fake example"

  def render(assigns) do
    ~F"""
    The code
    """
  end
end
