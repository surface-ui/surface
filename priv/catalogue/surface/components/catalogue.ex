defmodule Surface.Components.Catalogue do
  use Surface.Catalogue

  load_asset "assets/bulma.min.css", as: :bulma_css

  @impl true
  def config() do
    [
      head_css: """
      <style>#{@bulma_css}</style>
      """
    ]
  end
end
