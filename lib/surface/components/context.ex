defmodule Surface.Components.Context do
  @moduledoc """
  A built-in component that allows users to set and retrieve values from the context.
  """

  use Surface.Component

  @doc """
  Set a value to the context.

  ## Usage

  ```
  <Context set={{ key, value, options }}>
    ...
  </Context>
  ```

  Where `key` is the key which will be used to store the `value`.

  Available options:

    * `scope` - The scope where the value will be stored. If no scope is
    provided, the value is stored in root of the context map.

  ## Example

  ```
  <Context set={{ :form, form, scope: __MODULE__ }}>
    ...
  </Context>
  ```
  """
  property set, :context_set, accumulate: true, default: []

  @doc """
  Retrieves a value from the context.

  ## Usage

  ```
  <Context get={{ key, options }}>
    ...
  </Context>
  ```

  Where `key` is the key that was be used to store the `value`.

  Available options:

    * `scope` - The scope where the value was previously stored. If no scope is
    provided, the value is retrieved from the root of the context map.

    * `as` - The name of the assign that will hold the retrieved value.

  ## Example

  ```
  <Context
    get={{ :form, scope: Form }}
    get={{ :field, scope: Field, as: :my_field }}>
    <MyTextInput form={{ @form }} field={{ @my_field }} />
  </Context>
  ```
  """
  property get, :context_get, accumulate: true, default: []

  @doc "The content of the `<Context>`"
  slot default, required: true

  def transform(node) do
    Module.put_attribute(node.meta.caller.module, :use_context?, true)
    node
  end

  def render(assigns) do
    ~H"""
    {{ render_inner(@inner_content, {:__default__, 0, %{}, context_map(@__context__, @set, @get)}) }}
    """
  end

  @doc """
  Retrieve a value from the context.

  The `opts` argument can contain any option accepted by the `get` property,
  except `:as`, which is ignored.
  """
  def get(assigns, key, opts) do
    {key, _as} = normalize_get({key, opts})
    assigns.__context__[key]
  end

  defp context_map(context, sets, _gets) do
    Enum.reduce(sets, context, fn set, acc ->
      {key, value} = normalize_set(set)
      Map.put(acc, key, value)
    end)
  end

  defp normalize_set({key, value, opts}) do
    case Keyword.get(opts, :scope) do
      nil ->
        {key, value}

      scope ->
        {{scope, key}, value}
    end
  end

  def normalize_get({key, opts}) do
    full_key =
      case Keyword.get(opts, :scope) do
        nil ->
          key

        scope ->
          {scope, key}
      end

    {full_key, Keyword.get(opts, :as, key)}
  end
end
