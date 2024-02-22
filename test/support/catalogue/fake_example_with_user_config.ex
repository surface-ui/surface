defmodule Surface.Catalogue.FakeExampleWithUserConfig do
  use Surface.Catalogue.Example,
    subject: Surface.FakeComponent,
    head_css: "User's fake css",
    head_js: "User's fake js"

  def render(assigns) do
    ~F"""
    The code
    """
  end
end
