defmodule <%= inspect(web_module) %>.Components.Card.Examples do
  @moduledoc """
  Example using the `rounded` property and slots.
  """

  use Surface.Catalogue.Examples,
    subject: <%= inspect(web_module) %>.Components.Card

  alias <%= inspect(web_module) %>.Components.Card

  @example [
    title: "A rounded card example and Code split horizontal",
    direction: "horizontal",
    height: "360px",
    assert: ["Phoenix Framework", "rich interactive user-interfaces", "#surface", "#phoenix", "#tailwindcss"]
  ]

  @doc "A rounded card example with header, default, and footer slot"
  def rounded_card_example(assigns) do
    ~F"""
    <style>
      .tag {
        display: inline-block;
        background-color: #ddd;
        border-radius: 9999px;
        padding: 10px 8px;
        color: #888;
        font-weight: 500;
      }
    </style>

    <Card rounded>
      <:header>
        Phoenix Framework
      </:header>

      Start building rich interactive user-interfaces, writing minimal custom Javascript.
      Built on top of Phoenix LiveView, Surface leverages the amazing Phoenix Framework
      to provide a fast and productive solution to build modern web applications.

      <:footer>
        <span class="tag">#surface</span>
        <span class="tag">#phoenix</span>
        <span class="tag">#tailwindcss</span>
      </:footer>
    </Card>
    """
  end

  @example [
    title: "A Card example and Code split horizontal",
    direction: "horizontal",
    height: "360px",
    assert: ["Phoenix Framework", "rich interactive user-interfaces", "#surface", "#phoenix", "#tailwindcss"]
  ]

  @doc "A card example with header, default, and footer slot"
  def card_example(assigns) do
    ~F"""
    <style>
    .tag {
      display: inline-block;
      background-color: #ddd;
      border-radius: 9999px;
      padding: 10px 8px;
      color: #888;
      font-weight: 500;
    }
    </style>

    <Card>
      <:header>
        Phoenix Framework
      </:header>

      Start building rich interactive user-interfaces, writing minimal custom Javascript.
      Built on top of Phoenix LiveView, Surface leverages the amazing Phoenix Framework
      to provide a fast and productive solution to build modern web applications.

      <:footer>
        <span class="tag">#surface</span>
        <span class="tag">#phoenix</span>
        <span class="tag">#tailwindcss</span>
      </:footer>
    </Card>
    """
  end
end
