defmodule Surface.Components.FakeCatalogue do
  @behaviour Surface.Catalogue

  @impl true
  def config() do
    [
      head_css: "Catalogue's fake head css",
      head_js: "Catalogue's fake head js"
    ]
  end
end
