defmodule Surface.TypeHandler do
  @moduledoc false

  alias Surface.IOHelper

  @type clauses :: list(Macro.t())
  @type opts :: keyword(Macro.t())

  @callback expr_to_quoted(
              type :: atom(),
              attribute_name :: atom(),
              clauses(),
              opts(),
              module(),
              original :: String.t()
            ) :: {:ok, Macro.t()} | {:error, String.t()} | :error

  @callback expr_to_value(clauses :: list(), opts :: keyword()) ::
              {:ok, any()} | {:error, any()} | {:error, any(), String.t()}

  @callback value_to_html(name :: atom(), value :: any()) :: String.t()

  @callback update_prop_expr(expr :: Macro.t(), meta :: Surface.AST.Meta.t()) :: Macro.t()

  @optional_callbacks [
    expr_to_quoted: 6,
    expr_to_value: 2,
    value_to_html: 2,
    update_prop_expr: 2
  ]

  defmacro __using__(_) do
    quote do
      @behaviour unquote(__MODULE__)
      @default_handler unquote(__MODULE__).Default

      defdelegate expr_to_quoted(type, name, clauses, opts, module, original),
        to: @default_handler

      defdelegate expr_to_value(clauses, opts), to: @default_handler
      defdelegate value_to_html(name, value), to: @default_handler
      defdelegate update_prop_expr(expr, meta), to: @default_handler

      defoverridable expr_to_quoted: 6,
                     expr_to_value: 2,
                     value_to_html: 2,
                     update_prop_expr: 2
    end
  end

  def expr_to_quoted!(value, name, type, meta, original \\ nil) do
    original = original || value

    with {:ok, ast} <- normalize_expr(value, line: meta.line, file: meta.file),
         {clauses, opts} <- split_clauses_and_options(ast),
         true <- clauses != [] or opts != [],
         handler <- handler(type),
         {:ok, value} <- handler.expr_to_quoted(type, name, clauses, opts, meta, original) do
      value
    else
      {:error, {line, error, token}} ->
        IOHelper.syntax_error(
          error <> token,
          meta.file,
          line
        )

      {:error, expected} ->
        message = compile_error_message(type, name, original, meta.module, expected)
        IOHelper.compile_error(message, meta.file, meta.line)

      _ ->
        message = compile_error_message(type, name, original, meta.module)
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

  def attr_to_html(:boolean, name, value) do
    if value do
      [~S( ), to_string(name)]
    else
      ""
    end
  end

  def attr_to_html(type, name, value) do
    case handler(type).value_to_html(name, value) do
      string when string in ["", nil] ->
        ""

      string ->
        Phoenix.HTML.raw([" ", to_string(name), "=", ~S("), string, ~S(")])
    end
  end

  def update_prop_expr(type, value, meta) do
    handler(type).update_prop_expr(value, meta)
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
    #{expected}, got: {{#{value}}}.\
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

  defp handler(:boolean), do: __MODULE__.Boolean
  defp handler(:map), do: __MODULE__.Map
  defp handler(:keyword), do: __MODULE__.Keyword
  defp handler(:css_class), do: __MODULE__.CssClass
  defp handler(:style), do: __MODULE__.Style
  defp handler(:event), do: __MODULE__.Event
  defp handler(:phx_event), do: __MODULE__.PhxEvent
  defp handler(:generator), do: __MODULE__.Generator
  defp handler(:bindings), do: __MODULE__.Bindings
  defp handler(:list), do: __MODULE__.List
  defp handler(:static_list), do: __MODULE__.StaticList
  defp handler(_), do: __MODULE__.Default
end
