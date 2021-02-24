defmodule Surface.TypeHandler do
  @moduledoc false

  alias Surface.IOHelper

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

  @callback expr_to_value(clauses :: list(), opts :: keyword()) ::
              {:ok, any()} | {:error, any()} | {:error, any(), String.t()}

  @callback value_to_html(name :: atom(), value :: any()) ::
              {:ok, String.t() | nil | boolean()} | {:error, String.t()}

  @callback value_to_opts(name :: atom(), value :: any()) ::
              {:ok, any()} | {:error, String.t()}

  @callback update_prop_expr(expr :: Macro.t(), meta :: Surface.AST.Meta.t()) :: Macro.t()

  @optional_callbacks [
    literal_to_ast_node: 4,
    expr_to_quoted: 6,
    expr_to_value: 2,
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

      defdelegate literal_to_ast_node(type, name, value, meta), to: @default_handler

      defdelegate expr_to_quoted(type, name, clauses, opts, module, original),
        to: @default_handler

      defdelegate expr_to_value(clauses, opts), to: @default_handler
      defdelegate value_to_html(name, value), to: @default_handler
      defdelegate value_to_opts(name, value), to: @default_handler
      defdelegate update_prop_expr(expr, meta), to: @default_handler

      defoverridable literal_to_ast_node: 4,
                     expr_to_quoted: 6,
                     expr_to_value: 2,
                     value_to_html: 2,
                     value_to_opts: 2,
                     update_prop_expr: 2
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

  def expr_to_value!(type, name, clauses, opts, module, original) do
    case handler(type).expr_to_value(clauses, opts) do
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
    case handler(type).value_to_html(name, value) do
      {:ok, val} when val in ["", nil, false] ->
        ""

      {:ok, true} ->
        [~S( ), to_string(name)]

      {:ok, val} ->
        [" ", to_string(name), "=", ~S("), Phoenix.HTML.Safe.to_iodata(val), ~S(")]

      {:error, message} ->
        IOHelper.runtime_error(message)
    end
  end

  def attr_to_opts!(type, name, value) do
    case handler(type).value_to_opts(name, value) do
      {:ok, val} when val in ["", nil, false] ->
        []

      {:ok, val} ->
        [{name, val}]

      {:error, message} ->
        IOHelper.runtime_error(message)
    end
  end

  def update_prop_expr(type, value, meta) do
    handler(type).update_prop_expr(value, meta)
  end

  def runtime_prop_value!(module, name, value, node_alias) do
    type =
      attribute_type_and_opts(module, name, %{
        node_alias: node_alias || module,
        caller: __ENV__,
        line: __ENV__.line
      })

    expr_to_value!(type, name, [value], [], module, value)
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

  def attribute_type_and_opts(module, name, meta) do
    with true <- function_exported?(module, :__get_prop__, 1),
         prop when not is_nil(prop) <- module.__get_prop__(name) do
      {prop.type, prop.opts}
    else
      _ ->
        IOHelper.warn(
          "Unknown property \"#{to_string(name)}\" for component <#{meta.node_alias}>",
          meta.caller,
          fn _ ->
            meta.line
          end
        )

        {:string, []}
    end
  end

  defp runtime_error_message(type, name, value, module, original, details \\ nil) do
    details = if details, do: "\n" <> details, else: details
    {attr_name, attr_kind} = formatted_name_and_kind(name, module)

    """
    invalid value for #{attr_kind} #{attr_name}. \
    Expected a #{inspect(type)}, got: #{inspect(value)}.

    Original expression: {{#{original}}}
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
    "{{#{value}}}"
  end

  defp handler(:boolean), do: __MODULE__.Boolean
  defp handler(:atom), do: __MODULE__.Atom
  defp handler(:form), do: __MODULE__.Form
  defp handler(:map), do: __MODULE__.Map
  defp handler(:keyword), do: __MODULE__.Keyword
  defp handler(:explict_keyword), do: __MODULE__.ExplicitKeyword
  defp handler(:css_class), do: __MODULE__.CssClass
  defp handler(:style), do: __MODULE__.Style
  defp handler(:event), do: __MODULE__.Event
  defp handler(:phx_event), do: __MODULE__.PhxEvent
  defp handler(:generator), do: __MODULE__.Generator
  defp handler(:bindings), do: __MODULE__.Bindings
  defp handler(:list), do: __MODULE__.List
  defp handler(:static_list), do: __MODULE__.StaticList
  defp handler(:context_put), do: __MODULE__.ContextPut
  defp handler(:context_get), do: __MODULE__.ContextGet
  defp handler(:hook), do: __MODULE__.Hook
  defp handler(_), do: __MODULE__.Default
end
