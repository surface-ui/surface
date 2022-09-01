defmodule <%= inspect(web_module) %>.Components.CardExamples do
  @moduledoc """
  Example using the `rounded` property and slots.
  """

  use Surface.Catalogue.Examples,
    subject: <%= inspect(web_module) %>.Components.Card

  alias <%= inspect(web_module) %>.Components.Card

  @example [
    title: "rounded",
    height: "360px",
    assert: ["The header", "user-interfaces"]
  ]

  @doc "An example of a rounded card."
  def rounded_card_example(assigns) do
    ~F"""
    <Card rounded>
      <:header>
        The header
      </:header>

      Start building rich interactive user-interfaces,
      writing minimal custom Javascript. Built on top
      of Phoenix LiveView, Surface leverages the amazing
      Phoenix Framework to provide a fast and productive
      solution to build modern web applications.
    </Card>
    """
  end

  @example [
    title: "footer",
    height: "360px",
    assert: ["The header", "user-interfaces", "#surface", "#phoenix", "#tailwindcss"]
  ]

  @doc "An example of a card with footer."
  def card_with_footer_example(assigns) do
    ~F"""
    <style>
      .tag {
        display: inline-block;
        background-color: #ddd;
        border-radius: 9999px;
        padding: 3px 10px;
        color: #888;
        font-weight: 500;
      }
    </style>

    <Card>
      <:header>
        The header
      </:header>

      Start building rich interactive user-interfaces,
      writing minimal custom Javascript. Built on top
      of Phoenix LiveView, Surface leverages the amazing
      Phoenix Framework to provide a fast and productive
      solution to build modern web applications.

      <:footer>
        <span class="tag">#surface</span>
        <span class="tag">#phoenix</span>
        <span class="tag">#tailwindcss</span>
      </:footer>
    </Card>
    """
  end
end
