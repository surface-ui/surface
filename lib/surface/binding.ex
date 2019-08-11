defmodule Surface.Binding do

  defmacro __using__(_) do
    quote do
      import unquote(__MODULE__)
      Module.register_attribute __MODULE__, :bindings, accumulate: true, persist: false
      Module.register_attribute __MODULE__, :children, accumulate: true, persist: false
      @before_compile unquote(__MODULE__)
    end
  end

  defmacro __before_compile__(env) do
    children = Module.get_attribute(env.module, :children) |> Map.new

    children_def =
      quote do
        def __children__() do
          unquote(Macro.escape(children))
        end
      end

    children_bindings =
      for {id, mod} <- children, {{comp, binding}, assign} <- mod.__bindings__(), into: %{} do
        {{Surface.BaseComponent.concat_ids(id, comp), binding}, {id, assign}}
      end

    bindings =
      Module.get_attribute(env.module, :bindings)
      |> Map.new
      |> Map.merge(children_bindings)

    bindings_def =
      quote do
        def __bindings__() do
          unquote(Macro.escape(bindings))
        end
      end

    [children_def, bindings_def]
  end

  def assings_to_bindings_map(bindings, comp_id, assigns) do
    for {{^comp_id, binding}, assign} <- bindings, into: %{} do
      {binding, assigns[find_assign(bindings, assign)]}
    end
  end

  def bindings_map_to_assigns(bindings, comp_id, bindings_map) do
    for {binding, value} <- bindings_map, into: [] do
      {find_assign(bindings, {comp_id, binding}), value}
    end
  end

  defp find_assign(_bindings, assign) when is_atom(assign) do
    assign
  end

  defp find_assign(bindings, assign) do
    find_assign(bindings, bindings[assign])
  end
end
