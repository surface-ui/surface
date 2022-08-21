defmodule Surface.Components.Context do
  @moduledoc """
  A built-in module and component that allows users to set and retrieve values
  to/from the context.
  """

  use Surface.Component

  alias Surface.AST
  alias Surface.IOHelper
  alias Phoenix.LiveView.Socket

  defguardp is_socket_or_assigns(value) when is_struct(value, Socket) or is_map_key(value, :__changed__)

  @doc """
  Puts a value into the context.

  ## Usage

  ```
  <Context put={scope, values}>
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
  <Context put={__MODULE__, form: @form}>
    ...
  </Context>
  ```

  Without scope:

  ```
  <Context put={key1: @value1, key2: "some other value"}>
    ...
  </Context>
  ```

  """
  prop put, :context_put, accumulate: true, default: []

  @doc """
  Retrieves a set of values from the context binding them to local variables.

  ## Usage

  ```
  <Context get={scope, bindings}>
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
    get={Form, form: form}
    get={Field, field: my_field}>
    <MyTextInput form={form} field={my_field} />
  </Context>
  ```
  """
  prop get, :context_get, accumulate: true, default: []

  @doc "The content of the `<Context>`"
  slot default, required: true

  @doc false
  def transform(node) do
    maybe_warn_on_context_put(node)

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

    update_let_for_slot_entry(node, :default, let)
  end

  @doc false
  def render(assigns) do
    ~F"""
    {render_slot(@default, context_map(@__context__, @put, @get))}
    """
  end

  @doc """
  Puts a value into the context.

  ## Usage

      Context.put(socket_or_assigns, scope, values)

  Where:

    * `socket_or_assigns` - The socket or assigns where the values will be stored.

    * `scope` - Optional. Is an atom representing the scope where the values will
      be stored. If no scope is provided, the value is stored at the root of the
      context map.

    * `values`- A keyword list containing the key-value pairs that will be stored
      in the context.

  ## Examples

  With scope:

      Context.put(__MODULE__, form: @form)

  Without scope:

      Context.put=(key1: @value1, key2: "some other value")

  """
  def put(socket_or_assigns, scope \\ nil, values)

  def put(socket_or_assigns, scope, values) when is_socket_or_assigns(socket_or_assigns) do
    context =
      socket_or_assigns
      |> get_assigns_context()
      |> put_values(scope, values)

    Phoenix.LiveView.assign(socket_or_assigns, :__context__, context)
  end

  def put(socket_or_assigns, _scope, _values) do
    raise ArgumentError, expects_socket_or_assigns_message("put/3", socket_or_assigns)
  end

  @doc """
  Retrieves a value from the context.

  ## Usage

  ```
  Context.get(socket_or_assigns, scope, key)
  ```

  Where:

    * `socket_or_assigns` - The socket or assigns where the values will be retrieved from.

    * `scope` - Optional. Is an atom representing the scope where the values will
      be stored. If no scope is provided, the value is stored at the root of the
      context map.

    * `key`- the key to look for when retrieving the value.

  ## Examples

      form = Context.get(assigns, Form, :form)
      field = Context.get(assigns, Field, :field)

      ...

      ~F"\""
      <MyTextInput form={form} field={field} />
      "\""
  """
  def get(socket_or_assigns, scope \\ nil, key)

  def get(socket_or_assigns, scope, key) when is_socket_or_assigns(socket_or_assigns) do
    socket_or_assigns
    |> get_assigns_context()
    |> Map.get(normalize_key(scope, key))
  end

  def get(socket_or_assigns, _scope, _values) do
    raise ArgumentError, expects_socket_or_assigns_message("get/3", socket_or_assigns)
  end

  defp expects_socket_or_assigns_message(fun, value) do
    "#{fun} expects a socket or an assigns map from a function component as first argument, got: #{inspect(value)}"
  end

  defp get_assigns_context(%Socket{} = socket) do
    socket.assigns[:__context__] || %{}
  end

  defp get_assigns_context(assigns) do
    assigns[:__context__] || %{}
  end

  defp context_map(context, puts, gets) do
    updated_context =
      for {scope, values} <- puts, reduce: %{} do
        acc -> put_values(acc, scope, values)
      end

    full_context = Map.merge(context, updated_context)

    props =
      for {scope, values} <- gets, {key, _value} <- values, into: %{} do
        key =
          if scope == nil do
            key
          else
            {scope, key}
          end

        {key, Map.get(full_context, key, nil)}
      end

    {props, updated_context}
  end

  defp normalize_key(nil, key) do
    key
  end

  defp normalize_key(scope, key) do
    {scope, key}
  end

  defp update_let_for_slot_entry(node, slot_entry_name, let) do
    updated =
      node.slot_entries
      |> Map.get(slot_entry_name, [])
      |> Enum.map(fn slot_entry -> %{slot_entry | let: let} end)

    slot_entries = Map.put(node.slot_entries, slot_entry_name, updated)

    Map.put(node, :slot_entries, slot_entries)
  end

  def has_vars?(ast) do
    {_, value} =
      Macro.prewalk(ast, false, fn
        {:@, _meta, _args}, acc ->
          {[], acc}

        {name, _meta, ctx}, _acc when is_atom(name) and ctx in [Elixir, nil] ->
          {[], true}

        expr, acc ->
          {expr, acc}
      end)

    value
  end

  defp put_values(context, scope, values) do
    new_values =
      for {key, value} <- values, reduce: %{} do
        acc -> Map.put(acc, normalize_key(scope, key), value)
      end

    Map.merge(context, new_values)
  end

  defp maybe_warn_on_context_put(node) do
    puts = Enum.filter(node.props, fn %{name: name} -> name == :put end)

    for %AST.Attribute{value: %AST.AttributeExpr{value: expr, meta: meta}} <- puts do
      unless Macro.quoted_literal?(expr) or has_vars?(expr) do
        message = """
        using <Context put={...}> to store values that don't depend on variables is not recommended.

        Hint: If the values you're storing in the context depend only on the component's assigns, \
        use `Context.put/3` instead.

        # On live components or live views
        socket = Context.put(socket, timezone: "UTC")

        # On components
        assigns = Context.put(assigns, timezone: "UTC")
        """

        IOHelper.warn(message, meta.caller, meta.file, meta.line)
      end
    end
  end
end
