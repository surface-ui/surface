defmodule Surface.Catalogue.FakePlayground do
  use Surface.Catalogue.Playground,
    subject: Surface.Components.FakeButton,
    catalogue: Surface.Components.FakeCatalogue

  data props, :map,
    default: %{
      label: "My label"
    }

  def render(assigns) do
    ~H"""
    <For each={{prop, value} <- @props}>
      {prop}: {value}
    </For>
    """
  end
end
