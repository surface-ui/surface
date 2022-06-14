defmodule Surface.Components.Form.TextArea.Playground do
  use Surface.Catalogue.Playground,
    catalogue: Surface.Components.Catalogue,
    subject: Surface.Components.Form.TextArea,
    height: "170px"

  @props [
    rows: "4",
    cols: "40",
    class: ["textarea"],
    opts: [placeholder: "The textarea's content"]
  ]
end
