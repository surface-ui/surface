defmodule Surface.Binding do

  defmacro __using__(_) do
    quote do
      import unquote(__MODULE__)
      Module.register_attribute __MODULE__, :bindings_mapping, accumulate: true, persist: false
      Module.register_attribute __MODULE__, :children, accumulate: true, persist: false
      @before_compile unquote(__MODULE__)
    end
  end

  defmacro __before_compile__(env) do
    children = Module.get_attribute(env.module, :children) |> Enum.uniq()

    children_def =
      quote do
        def __children__() do
          unquote(Macro.escape(children))
        end
      end

    children_bindings_mapping =
      for {id, mod} <- children, {{comp, binding}, assign} <- mod.__bindings_mapping__(), into: %{} do
        {{id <> ">" <> comp, binding}, {id, assign}}
      end

    bindings_mapping =
      Module.get_attribute(env.module, :bindings_mapping)
      |> Enum.uniq()
      |> Map.new
      |> Map.merge(children_bindings_mapping)

    bindings_mapping_def =
      quote do
        def __bindings_mapping__() do
          unquote(Macro.escape(bindings_mapping))
        end
      end

    [children_def, bindings_mapping_def]
  end

  def assings_to_bindings(mappings, comp_id, assigns) do
    for {{^comp_id, binding}, assign} <- mappings, into: %{} do
      {binding, assigns[find_assign(mappings, assign)]}
    end
  end

  def bindings_to_assigns(mappings, comp_id, bindings) do
    for {binding, value} <- bindings, into: [] do
      {find_assign(mappings, {comp_id, binding}), value}
    end
  end

  defp find_assign(_mappings, assign) when is_atom(assign) do
    assign
  end

  defp find_assign(mappings, assign) do
    find_assign(mappings, mappings[assign])
  end
end
