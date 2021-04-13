defmodule Surface.Components.Form.TextArea.Playground do
  use Surface.Catalogue.Playground,
    catalogue: Surface.Components.Catalogue,
    subject: Surface.Components.Form.TextArea,
    height: "170px"

  data props, :map,
    default: %{
      rows: "4",
      cols: "40",
      class: ["textarea"],
      opts: [placeholder: "The textarea's content"]
    }

  def render(assigns) do
    ~H"""
    <TextArea :props={{ @props }}/>
    """
  end
end
