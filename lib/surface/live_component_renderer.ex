defmodule Surface.LiveComponentRenderer do
  require Phoenix.LiveView

  def render(socket, module, props) do
    do_render(socket, module, props, [])
  end

  def render(socket, module, props, do: block) do
    do_render(socket, module, props, block)
  end

  defp do_render(socket, module, props, content) do
    props =
      props
      |> Map.put(:content, content)
      |> put_default_props(module)

    Phoenix.LiveView.live_component(socket, module, Keyword.new(props), content)
  end

  defp put_default_props(props, mod) do
    Enum.reduce(mod.__props(), props, fn %{name: name, default: default}, acc ->
      Map.put_new(acc, name, default)
    end)
  end
end
