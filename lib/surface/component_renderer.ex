defmodule Surface.ComponentRenderer do
  alias Surface.BaseComponent.{DataContent, LazyContent}

  def render(module, props) do
    do_render(module, props, [])
  end

  def render(module, props, do: block) do
    do_render(module, props, block)
  end

  defp do_render(module, props, content) do
    props =
      props
      |> Map.put(:content, content)
      |> put_default_props(module)

    case module.render(props) do
      {:data, data} ->
        case data do
          %{content: {:safe, [%LazyContent{func: func}]}} ->
            %DataContent{data: Map.put(data, :inner_content, func), component: module}
          _ ->
            %DataContent{data: data, component: module}
        end
      result ->
        result
    end
  end

  defp put_default_props(props, mod) do
    Enum.reduce(mod.__props(), props, fn %{name: name, default: default}, acc ->
      Map.put_new(acc, name, default)
    end)
  end
end
