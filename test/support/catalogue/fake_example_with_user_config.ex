defmodule Surface.Catalogue.FakeExampleWithUserConfig do
  use Surface.Catalogue.Example,
    subject: Surface.Components.Form,
    head_css: "User's fake css",
    head_js: "User's fake js"

  def render(assigns) do
    ~H"""
    The code
    """
  end
end
