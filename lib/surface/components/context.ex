defmodule Surface.Components.Context do
  @moduledoc """
  A built-in component that allows users to set and retrieve values from the context.
  """

  use Surface.Component

  alias Surface.AST

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

  property __default_content__, :fun
  property __slot_content__, :keyword, default: []

  @doc "The content of the `<Context>`"
  slot default, required: true

  def render(assigns) do
    ~H"""
    {{ @__original_inner_content.(slot_kw() ++ context_assigns_kw(@__context__, @set, @get, @__default_content__, @__slot_content__)) }}
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

  def transform(
        %Surface.AST.Component{module: Surface.Components.Context, props: props, meta: node_meta} =
          node
      ) do
    case Enum.find(props, fn %{name: name} -> name == :set end) do
      nil ->
        node

      _ ->
        {default_content_prop, props} =
          extract_or_create_prop(
            props,
            :__default_content__,
            :fun,
            %AST.AttributeExpr{
              original: " @inner_content ",
              value:
                quote do
                  @inner_content
                end,
              meta: node_meta
            },
            node_meta
          )

        {slot_content_prop, props} =
          extract_or_create_prop(
            props,
            :__slot_content__,
            :keyword,
            slot_content_prop_value(node_meta),
            node_meta
          )

        props = [default_content_prop | [slot_content_prop | props]]

        %{
          node
          | props: props
        }
    end
  end

  defp slot_content_prop_value(%{caller: caller} = meta) do
    value =
      caller
      |> Surface.API.get_slots()
      |> Enum.reject(fn %{name: name} -> name == :default end)
      |> Enum.map(fn %{name: name} -> {name, at_ref(name)} end)

    %AST.AttributeExpr{
      original: Macro.to_string(value),
      value: value,
      meta: meta
    }
  end

  defp at_ref(name) do
    {:@, [generated: true], [{name, [generated: true], nil}]}
  end

  defp extract_or_create_prop(props, attr_name, attr_type, default, meta) do
    props
    |> Enum.split_with(fn
      %{name: name} when name == attr_name -> true
      _ -> false
    end)
    |> case do
      {[prop], not_prop} ->
        {prop, not_prop}

      {_, not_prop} ->
        {%AST.Attribute{
           name: attr_name,
           type: attr_type,
           value: default,
           meta: meta
         }, not_prop}
    end
  end

  defp slot_kw() do
    [__slot__: {:__default__, 0}]
  end

  defp context_assigns_kw(context, sets, gets, default_content, slot_content) do
    updated_context =
      Enum.reduce(sets, context, fn set, acc ->
        {key, value} = normalize_set(set)
        Map.put(acc, key, value)
      end)

    context_kw(updated_context, sets) ++
      context_gets_kw(updated_context, gets) ++
      updated_inner_content(updated_context, default_content) ++
      updated_slot_inner_content(updated_context, slot_content)
  end

  defp updated_slot_inner_content(context, slots) do
    Enum.map(slots, fn {slot_name, slot_entries} ->
      slot_entries =
        Enum.map(slot_entries, fn slot ->
          Map.put(slot, :inner_content, fn args ->
            slot.inner_content.(Keyword.merge([__context__: context], args))
          end)
        end)

      {slot_name, slot_entries}
    end)
  end

  defp updated_inner_content(_context, nil) do
    []
  end

  defp updated_inner_content(context, inner_content) do
    [inner_content: fn args -> inner_content.(Keyword.merge([__context__: context], args)) end]
  end

  defp context_kw(context, sets) do
    if sets == [] do
      []
    else
      [__context__: context]
    end
  end

  defp context_gets_kw(context, gets) do
    Enum.map(gets, fn get ->
      {key, name} = normalize_get(get)
      {name, context[key]}
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

  defp normalize_get({key, opts}) do
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
