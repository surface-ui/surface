defmodule Surface.Components.Context do
  @moduledoc """
  > #### Deprecation warning {: .warning}
  >
  > Using this module as a component with `<Context>` has been deprecated. Support for
  > scope-aware context will be removed in `v0.13` due to the lack of built-in support for
  > the feature in Liveview itself, which leads to inefficient diff-tracking when using it.
  >
  > Global context related functions like `Context.put/3` and `Context.get/3`, as well as data/prop's
  > option `:from_context`, will be kept and recommended as their usage don't affect diff-tracking
  > negatively.

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
      |> Enum.flat_map(fn {:__context_get__, scope, values} ->
        if scope == nil do
          values
        else
          Enum.map(values, fn {key, value} -> {{scope, key}, value} end)
        end
      end)

    update_let_for_slot_entry(node, :default, let)
  end

  if Mix.env() != :test do
    @deprecated "Use `Context.put/3`, `Context.get/3` or the data/prop's option `:from_context` instead"
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

      Context.put(key1: @value1, key2: "some other value")

  > **Note**: Whenever using `Context.put/3` inside the [`update/2`](`c:Phoenix.LiveComponent.update/2`) callback, make sure you call it passing the `socket`, not the `assigns`.
  """
  def put(socket_or_assigns, scope \\ nil, values)

  def put(socket_or_assigns, scope, values) when is_socket_or_assigns(socket_or_assigns) do
    context =
      socket_or_assigns
      |> get_assigns_context()
      |> put_values(scope, values)

    Phoenix.Component.assign(socket_or_assigns, :__context__, context)
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

  > **Note**: Whenever using `Context.get/3` inside the [`update/2`](`c:Phoenix.LiveComponent.update/2`) callback, make sure you call it passing the `socket`, not the `assigns`.
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

  @doc """
  Copies a value from the context directly into `socket_or_assigns`.

  ## Usage

      # Simple key
      Context.copy_assign(socket_or_assigns, key)

      # Simple key with options
      Context.copy_assign(socket_or_assigns, key, opts)

      # Key with scope
      Context.copy_assign(socket_or_assigns, {scope, key})

      # Key with scope + options
      Context.copy_assign(socket_or_assigns, {scope, key}, opts)

  ## Options

    * `:as` - Optional. The key to store the value. Default is the `key` without the scope.

  """
  def copy_assign(socket_or_assigns, key, opts \\ []) do
    {scope, key, to_key} = process_key(key, opts)
    value = get(socket_or_assigns, scope, key)

    Phoenix.Component.assign(socket_or_assigns, to_key, value)
  end

  @doc """
  Copies a value from the context directly into `socket_or_assigns`
  if the value hasn't already been set or if it's `nil`.

  The value will be saved using the same `key`.

  ## Usage

      Context.maybe_copy_assign(socket_or_assigns, scope, key)

  """
  def maybe_copy_assign(socket_or_assigns, key, opts \\ []) do
    {scope, key, to_key} = process_key(key, opts)

    cond do
      get_assigns(socket_or_assigns)[to_key] != nil ->
        socket_or_assigns

      value = get(socket_or_assigns, scope, key) ->
        Phoenix.Component.assign(socket_or_assigns, to_key, value)

      true ->
        socket_or_assigns
    end
  end

  @doc """
  Copies a value from the context directly into `socket_or_assigns`.

  It raises a runtime error in case the value is still `nil` after
  after the operation. This is useful whenever you expect a non-nil
  value coming either explicitly passed a `prop` or inplictly through
  the context.

  The value will be saved using the same `key`.

  ## Usage

      Context.maybe_copy_assign!(socket_or_assigns, scope, key)

  """
  def maybe_copy_assign!(socket_or_assigns, key, opts \\ []) do
    socket_or_assigns = maybe_copy_assign(socket_or_assigns, key, opts)

    {scope, key, to_key} = process_key(key, opts)

    if get_assigns(socket_or_assigns)[to_key] != nil do
      socket_or_assigns
    else
      scope_and_key = if scope, do: "#{inspect(scope)}, #{key}", else: key

      message = """
      expected assign #{inspect(key)} to have a value, got: `nil`.

      If you're expecting a value from a prop, make sure you're passing it.

      ## Example

          <YourComponent #{key}={...}>

      If you expecting a value from the context, make sure you have used `Context.put/3` \
      to store the value in a parent component.

      ## Example

          Context.put(socket_or_assigns, #{scope_and_key}: ...)

      If you expecting the value to come from a parent component's slot, make sure you add \
      the parent component to the `:propagate_context_to_slots` list in your config.

      ## Example

          config :surface, :propagate_context_to_slots, [
            # For module components
            ModuleComponentStoringTheValue,
            # For function components
            {FunctionComponentStoringTheValue, :func}
            ...
          ]
      """

      raise message
    end
  end

  defp expects_socket_or_assigns_message(fun, value) do
    "#{fun} expects a socket or an assigns map from a function component as first argument, got: #{inspect(value)}"
  end

  defp get_assigns_context(socket_or_assigns) do
    get_assigns(socket_or_assigns)[:__context__] || %{}
  end

  defp get_assigns(%Socket{} = socket) do
    socket.assigns
  end

  defp get_assigns(assigns) do
    assigns
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

    {props, nil, updated_context}
  end

  @doc false
  def normalize_key(nil, key) do
    key
  end

  def normalize_key(scope, key) do
    {scope, key}
  end

  defp process_key(key, opts) do
    {scope, key} =
      case key do
        {k, v} -> {k, v}
        k -> {nil, k}
      end

    {scope, key, opts[:as] || key}
  end

  defp update_let_for_slot_entry(node, slot_entry_name, let) do
    updated =
      node.slot_entries
      |> Map.get(slot_entry_name, [])
      |> Enum.map(fn slot_entry ->
        %{slot_entry | let: %AST.AttributeExpr{meta: node.meta, value: {:%{}, [], let}}}
      end)

    slot_entries = Map.put(node.slot_entries, slot_entry_name, updated)

    Map.put(node, :slot_entries, slot_entries)
  end

  def has_vars?(ast) do
    {_, value} =
      Macro.prewalk(ast, false, fn
        {:@, _meta, _args}, acc ->
          {[], acc}

        {name, _meta, _args}, acc when name in [:__MODULE__, :__ENV__, :__STACKTRACE__, :__DIR__] ->
          {[], acc}

        {name, _meta, ctx}, _acc when is_atom(name) and is_atom(ctx) ->
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

    for %AST.Attribute{value: %AST.AttributeExpr{value: {_scope, expr}, meta: meta, original: original}} <- puts do
      unless Macro.quoted_literal?(expr) or has_vars?(expr) do
        message = """
        using <Context put=...> without depending on any variable has been deprecated.

        If you're storing values in the context only to propagate them through slots, \
        use the `context_put` property instead.

        # Example

            <#slot context_put={#{original}} ... />

        If the values must be available to all other child components in the template, \
        use `Context.put/3` instead.

        # Example

            socket_or_assigns = Context.put(socket_or_assigns, timezone: "UTC")
        """

        IOHelper.warn(message, meta.caller, meta.file, meta.line)
      end
    end
  end
end
