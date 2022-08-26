defmodule Surface.TypeHandler do
  @moduledoc false

  alias Surface.IOHelper
  alias Surface.Components.Dynamic

  @type clauses :: list(Macro.t())
  @type opts :: keyword(Macro.t())

  @callback literal_to_ast_node(
              type :: atom(),
              name :: atom(),
              value :: any(),
              meta :: Surface.AST.Meta.t()
            ) ::
              {:ok, Surface.AST.Literal.t() | Surface.AST.AttributeExpr.t()}
              | {:error, String.t()}
              | :error

  @callback expr_to_quoted(
              type :: atom(),
              name :: atom(),
              clauses(),
              opts(),
              module(),
              original :: String.t()
            ) :: {:ok, Macro.t()} | {:error, String.t()} | :error

  @callback expr_to_value(clauses :: list(), opts :: keyword(), ctx :: map()) ::
              {:ok, any()} | {:error, any()} | {:error, any(), String.t()}

  @callback value_to_html(name :: atom(), value :: any()) ::
              {:ok, String.t() | nil | boolean()} | {:error, String.t()}

  @callback value_to_opts(name :: atom(), value :: any()) ::
              {:ok, any()} | {:error, String.t()}

  @callback update_prop_expr(expr :: Macro.t(), meta :: Surface.AST.Meta.t()) :: Macro.t()

  @optional_callbacks [
    literal_to_ast_node: 4,
    expr_to_quoted: 6,
    expr_to_value: 3,
    value_to_html: 2,
    value_to_opts: 2,
    update_prop_expr: 2
  ]

  @boolean_tag_attributes [
    :allowfullscreen,
    :allowpaymentrequest,
    :async,
    :autofocus,
    :autoplay,
    :checked,
    :controls,
    :default,
    :defer,
    :disabled,
    :formnovalidate,
    :hidden,
    :ismap,
    :itemscope,
    :loop,
    :multiple,
    :muted,
    :nomodule,
    :novalidate,
    :open,
    :readonly,
    :required,
    :reversed,
    :selected,
    :typemustmatch,
    :"phx-page-loading"
  ]

  @phx_event_attributes Surface.Directive.Events.phx_events() |> Enum.map(&String.to_atom/1)

  defmacro __using__(_) do
    quote do
      @behaviour unquote(__MODULE__)
      @default_handler unquote(__MODULE__).Default

      if __MODULE__ != @default_handler do
        @impl true
        defdelegate literal_to_ast_node(type, name, value, meta), to: @default_handler

        @impl true
        defdelegate expr_to_quoted(type, name, clauses, opts, module, original),
          to: @default_handler

        @impl true
        defdelegate expr_to_value(clauses, opts, ctx), to: @default_handler
        @impl true
        defdelegate value_to_html(name, value), to: @default_handler
        @impl true
        defdelegate value_to_opts(name, value), to: @default_handler
        @impl true
        defdelegate update_prop_expr(expr, meta), to: @default_handler

        defoverridable literal_to_ast_node: 4,
                       expr_to_quoted: 6,
                       expr_to_value: 3,
                       value_to_html: 2,
                       value_to_opts: 2,
                       update_prop_expr: 2
      end
    end
  end

  def literal_to_ast_node!(type, name, value, meta) do
    case handler(type).literal_to_ast_node(type, name, value, meta) do
      {:ok, attr_value} ->
        attr_value

      {:error, expected} ->
        message = compile_error_message(type, name, as_literal(value), meta.module, expected)
        IOHelper.compile_error(message, meta.file, meta.line)

      _ ->
        message = compile_error_message(type, name, as_literal(value), meta.module)
        IOHelper.compile_error(message, meta.file, meta.line)
    end
  end

  def expr_to_quoted!(value, name, type, meta, original \\ nil) do
    original = original || value

    with {:ok, ast} <- normalize_expr(value, line: meta.line, file: meta.file),
         _ <- Surface.Compiler.Helpers.perform_assigns_checks(ast, meta),
         {clauses, opts} <- split_clauses_and_options(ast),
         true <- clauses != [] or opts != [],
         handler <- handler(type),
         {:ok, value} <- handler.expr_to_quoted(type, name, clauses, opts, meta, original) do
      value
    else
      {:error, {position, error, token}} ->
        IOHelper.syntax_error(
          error <> token,
          meta.file,
          Surface.Compiler.Helpers.position_to_line(position)
        )

      {:error, expected} ->
        message = compile_error_message(type, name, as_expr(original), meta.module, expected)
        IOHelper.compile_error(message, meta.file, meta.line)

      _ ->
        message = compile_error_message(type, name, as_expr(original), meta.module)
        IOHelper.compile_error(message, meta.file, meta.line)
    end
  end

  def expr_to_value!(type, name, clauses, opts, module, original, ctx) do
    case handler(type).expr_to_value(clauses, opts, ctx) do
      {:ok, value} ->
        value

      {:error, value} ->
        message = runtime_error_message(type, name, value, module, original)
        IOHelper.runtime_error(message)

      {:error, value, details} ->
        message = runtime_error_message(type, name, value, module, original, details)
        IOHelper.runtime_error(message)
    end
  end

  def attr_to_html!(type, name, value) do
    case attr_to_html(type, name, value) do
      {:ok, value} -> value
      {:error, message} -> IOHelper.runtime_error(message)
    end
  end

  def attr_to_html(type, name, value) do
    case handler(type).value_to_html(name, value) do
      {:ok, val} when val in ["", nil, false] ->
        {:ok, ""}

      {:ok, true} ->
        {:ok, [~S( ), to_string(name)]}

      {:ok, val} ->
        {:ok, Phoenix.HTML.Tag.attributes_escape([{name, val}])}

      {:error, message} ->
        {:error, message}
    end
  end

  def attr_to_opts!(type, name, value) do
    case handler(type).value_to_opts(name, value) do
      {:ok, val} when val in ["", nil, false] ->
        []

      {:ok, val} ->
        [{name, val}]

      {:ok, :value, ""} ->
        [{:value, ""}]

      {:error, message} ->
        IOHelper.runtime_error(message)
    end
  end

  def update_prop_expr(type, value, meta) do
    handler(type).update_prop_expr(value, meta)
  end

  def runtime_prop_value!(module, name, clauses, opts, node_alias, original, ctx) do
    caller = %Macro.Env{module: ctx.module}

    {type, type_opts} =
      attribute_type_and_opts(module, name, %{
        runtime: true,
        node_alias: node_alias || module,
        caller: caller,
        file: ctx.file,
        line: ctx.line
      })

    if Keyword.get(type_opts, :accumulate, false) do
      Enum.map(clauses, &expr_to_value!(type, name, [&1], opts, module, original, ctx))
    else
      if length(clauses) > 1 do
        message =
          if Keyword.get(type_opts, :root, false) do
            """
            the prop `#{name}` has been passed multiple times. Considering only the last value.

            Hint: Either specify the `#{name}` via the root property (`<#{node_alias} { ... }>`) or \
            explicitly via the #{name} property (`<#{node_alias} #{name}="...">`), but not both.
            """
          else
            """
            the prop `#{name}` has been passed multiple times. Considering only the last value.

            Hint: Either remove all redundant definitions or set option `accumulate` to `true`:

            ```
              prop #{name}, #{inspect(type)}, accumulate: true
            ```

            This way the values will be accumulated in a list.
            """
          end

        IOHelper.warn(message, caller, ctx.file, ctx.line)
      end

      expr_to_value!(type, name, [List.last(clauses)], opts, module, original, ctx)
    end
  end

  def attribute_type_and_opts(name) do
    attribute_type_and_opts(nil, name, nil)
  end

  def attribute_type_and_opts(nil, :class, _meta), do: {:css_class, []}

  def attribute_type_and_opts(nil, :style, _meta), do: {:style, []}

  def attribute_type_and_opts(nil, name, _meta) when name in @boolean_tag_attributes,
    do: {:boolean, []}

  def attribute_type_and_opts(nil, name, _meta) when name in @phx_event_attributes,
    do: {:phx_event, []}

  def attribute_type_and_opts(nil, _name, _meta), do: {:string, []}

  # TODO: If we add a property to define the list of available modules or create
  # the concept of interfaces, we could validate/retrieve the types and opts.
  def attribute_type_and_opts(Dynamic.Component, :module, _meta) do
    {:module, []}
  end

  def attribute_type_and_opts(Dynamic.Component, :function, _meta) do
    {:atom, []}
  end

  def attribute_type_and_opts(Dynamic.Component, _name, _meta) do
    {:dynamic, []}
  end

  def attribute_type_and_opts(Dynamic.LiveComponent, :module, _meta) do
    {:module, []}
  end

  def attribute_type_and_opts(Dynamic.LiveComponent, _name, _meta) do
    {:dynamic, []}
  end

  def attribute_type_and_opts(module, name, meta) do
    with true <- function_exported?(module, :__get_prop__, 1),
         prop when not is_nil(prop) <- module.__get_prop__(name) do
      {prop.type, prop.opts}
    else
      # The module is not loaded or it's a plain old phoenix (live) component
      false ->
        {:string, []}

      _ ->
        if Map.get(meta, :runtime, false) do
          IOHelper.warn(
            "Unknown property \"#{to_string(name)}\" for component <#{meta.node_alias}>",
            meta.caller,
            meta.file,
            meta.line
          )
        end

        {:string, []}
    end
  end

  defp runtime_error_message(type, name, value, module, original, details \\ nil) do
    name = name || Enum.find(module.__props__(), & &1.opts[:root]).name

    details = if details, do: "\n" <> details, else: details
    {attr_name, attr_kind} = formatted_name_and_kind(name, module)

    original_expr_msg = if original, do: "\nOriginal expression: {#{original}}", else: ""

    """
    invalid value for #{attr_kind} #{attr_name}. \
    Expected a #{inspect(type)}, got: #{inspect(value)}.
    #{original_expr_msg}
    #{details}\
    """
  end

  defp compile_error_message(type, name, value, module, expected \\ nil) do
    expected = expected || "Expected a #{inspect(type)}"
    {attr_name, attr_kind} = formatted_name_and_kind(name, module)

    """
    invalid value for #{attr_kind} #{attr_name}. \
    #{expected}, got: #{value}.\
    """
  end

  defp formatted_name_and_kind(name, module) do
    cond do
      to_string(name) |> String.starts_with?(":") ->
        {name, "directive"}

      module ->
        name = name || Enum.find(module.__props__(), & &1.opts[:root]).name

        {inspect("#{name}"), "property"}

      true ->
        {inspect("#{name}"), "attribute"}
    end
  end

  defp normalize_expr(expr, opts) when is_binary(expr) do
    with {:ok, {:wrap, _, ast}} <- Code.string_to_quoted("wrap(#{expr})", opts) do
      {:ok, ast}
    end
  end

  defp normalize_expr(expr, _opts) do
    {:ok, [expr]}
  end

  defp split_clauses_and_options(clauses_and_options) do
    with [[_ | _] = opts | clauses] <- Enum.reverse(clauses_and_options),
         true <- Keyword.keyword?(opts) do
      {Enum.reverse(clauses), opts}
    else
      _ ->
        {clauses_and_options, []}
    end
  end

  defp as_literal(value) do
    inspect(value)
  end

  defp as_expr(value) do
    "{#{value}}"
  end

  defp handler(:boolean), do: __MODULE__.Boolean
  defp handler(:atom), do: __MODULE__.Atom
  defp handler(:form), do: __MODULE__.Form
  defp handler(:map), do: __MODULE__.Map
  defp handler(:keyword), do: __MODULE__.Keyword
  defp handler(:css_class), do: __MODULE__.CssClass
  defp handler(:style), do: __MODULE__.Style
  defp handler(:event), do: __MODULE__.Event
  defp handler(:phx_event), do: __MODULE__.PhxEvent
  defp handler(:generator), do: __MODULE__.Generator
  defp handler(:list), do: __MODULE__.List
  defp handler(:static_list), do: __MODULE__.StaticList
  defp handler(:context_put), do: __MODULE__.ContextPut
  defp handler(:context_get), do: __MODULE__.ContextGet
  defp handler(:hook), do: __MODULE__.Hook
  defp handler(:dynamic), do: __MODULE__.Dynamic
  defp handler(:let_arg), do: __MODULE__.LetArg
  defp handler(:render_slot), do: __MODULE__.RenderSlot
  defp handler(_), do: __MODULE__.Default
end
