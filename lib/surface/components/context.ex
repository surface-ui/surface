defmodule Surface.Components.Context do
  @moduledoc """
  A built-in component that allows users to set and retrieve values from the context.
  """

  use Surface.Component

  @doc """
  Puts a value into the context.

  ## Usage

  ```
  <Context put={{ scope, values }}>
    ...
  </Context>
  ```

  Where:

    * `scope` - Optional. Is an atom representing the scope where the values will
      be stored. If no scope is provided, the value is stored at the root of the
      context map.

    * `values`- A keyword list containing the key-value pairs that will be stored
      in the context.

  ## Examples

  With scope:

  ```
  <Context put={{ __MODULE__, form: @form }}>
    ...
  </Context>
  ```

  Without scope:

  ```
  <Context put={{ key1: @value1, key2: "some other value" }}>
    ...
  </Context>
  ```

  """
  prop put, :context_put, accumulate: true, default: []

  @doc """
  Retrieves a set of values from the context binding them to local variables.

  ## Usage

  ```
  <Context get={{ scope, bindings }}>
    ...
  </Context>
  ```

  Where:

    * `scope` - Optional. Is an atom representing the scope where the values will
      be stored. If no scope is provided, the value is stored at the root of the
      context map.

    * `bindings`- A keyword list of bindings that will be retrieved from the context
      as local variables.

  ## Examples

  ```
  <Context
    get={{ Form, form: form }}
    get={{ Field, field: my_field }}>
    <MyTextInput form={{ form }} field={{ my_field }} />
  </Context>
  ```
  """
  prop get, :context_get, accumulate: true, default: []

  @doc "The content of the `<Context>`"
  slot default, required: true

  def transform(node) do
    Module.put_attribute(node.meta.caller.module, :use_context?, true)

    let =
      node.props
      |> Enum.filter(fn %{name: name} -> name == :get end)
      |> Enum.map(fn %{value: %{value: value}} -> value end)
      |> Enum.flat_map(fn {scope, values} ->
        if scope == nil do
          values
        else
          Enum.map(values, fn {key, value} -> {{scope, key}, value} end)
        end
      end)

    update_let_for_template(node, :default, let)
  end

  def render(assigns) do
    ~H"""
    {{
      case context_map(@__context__, @put, @get) do
        {ctx, props} -> render_block(@inner_block, {:default, 0, props, ctx})
      end
    }}
    """
  end

  defp context_map(context, puts, gets) do
    ctx =
      for {scope, values} <- puts, {key, value} <- values, reduce: context do
        acc ->
          {full_key, value} = normalize_set(scope, key, value)
          Map.put(acc, full_key, value)
      end

    props =
      for {scope, values} <- gets, {key, _value} <- values, into: %{} do
        key =
          if scope == nil do
            key
          else
            {scope, key}
          end

        {key, Map.get(ctx, key, nil)}
      end

    {ctx, props}
  end

  defp normalize_set(nil, key, value) do
    {key, value}
  end

  defp normalize_set(scope, key, value) do
    {{scope, key}, value}
  end

  defp update_let_for_template(node, template_name, let) do
    updated =
      node.templates
      |> Map.get(template_name, [])
      |> Enum.map(fn template -> %{template | let: let} end)

    templates = Map.put(node.templates, template_name, updated)

    Map.put(node, :templates, templates)
  end
end
