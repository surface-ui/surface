defmodule Surface do
  alias Surface.Translator

  defmacro sigil_H({:<<>>, _, [string]}, _) do
    line_offset = __CALLER__.line + 1
    string
    |> Translator.run(line_offset, __CALLER__)
    |> EEx.compile_string(engine: Phoenix.LiveView.Engine, line: line_offset)
  end

  def component(module, assigns) do
    module.render(assigns)
  end

  def component(module, assigns, []) do
    module.render(assigns)
  end

  def put_default_props(props, mod) do
    Enum.reduce(mod.__props(), props, fn %{name: name, default: default}, acc ->
      Map.put_new(acc, name, default)
    end)
  end

  def css_class(list) when is_list(list) do
    Enum.reduce(list, [], fn item, classes ->
      case item do
        {class, true} ->
          [to_kebab_case(class) | classes]
        class when is_binary(class) or is_atom(class) ->
          [to_kebab_case(class) | classes]
        _ ->
          classes
      end
    end) |> Enum.reverse() |> Enum.join(" ")
  end

  def css_class(value) when is_binary(value) do
    value
  end

  # TODO: Find a better way to do this
  defp to_kebab_case(value) do
    value
    |> to_string()
    |> Macro.underscore()
    |> String.replace("_", "-")
  end
end
