defmodule Surface.Components.Form.TextArea.Example01 do
  use Surface.Catalogue.Example,
    catalogue: Surface.Components.Catalogue,
    subject: Surface.Components.Form.TextArea,
    height: "170px"

  def render(assigns) do
    ~H"""
    <TextArea
      rows="4"
      class="textarea"
      opts={{ placeholder: "4 lines of textarea" }}
    />
    """
  end
end
