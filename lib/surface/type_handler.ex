defmodule Surface.TypeHandler do
  @moduledoc false

  alias Surface.IOHelper

  # TODO: [Type] Validate the expression at compile-time if possible, e.g. literals, typed assigns
  # @callback validate_expr(clauses :: [Macro.t()], opts :: keyword(Macro.t())) :: {:ok, clauses, opts} | :error | {:error, message}

  @callback expr_to_value(clauses :: list(), opts :: keyword()) ::
              {:ok, any()} | {:error, any()} | {:error, any(), Striong.t()}

  @callback value_to_html(name :: atom(), value :: any()) :: String.t()

  @callback update_prop_expr(expr :: Macro.t(), meta :: Surface.AST.Meta.t()) :: Macro.t()

  @optional_callbacks [expr_to_value: 2, value_to_html: 2, update_prop_expr: 2]

  defmacro __using__(_) do
    quote do
      @behaviour unquote(__MODULE__)
      @default_handler unquote(__MODULE__).Default

      defdelegate expr_to_value(clauses, opts), to: @default_handler
      defdelegate value_to_html(name, value), to: @default_handler
      defdelegate update_prop_expr(expr, meta), to: @default_handler

      defoverridable unquote(__MODULE__)
    end
  end

  def expr_to_value(type, name, clauses, opts, module, original) do
    case handler(type).expr_to_value(clauses, opts) do
      {:ok, value} ->
        value

      {:error, value} ->
        message = error_message(type, name, value, module, original)
        IOHelper.runtime_error(message)

      {:error, value, details} ->
        message = error_message(type, name, value, module, original, details)
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

  defp handler(:boolean), do: __MODULE__.Boolean
  defp handler(:map), do: __MODULE__.Map
  defp handler(:keyword), do: __MODULE__.Keyword
  defp handler(:css_class), do: __MODULE__.CssClass
  defp handler(:event), do: __MODULE__.Event
  defp handler(:phx_event), do: __MODULE__.PhxEvent
  defp handler(_), do: __MODULE__.Default

  defp error_message(type, name, value, module, original, details \\ nil) do
    details = if details, do: "\n" <> details, else: details

    """
    invalid value for #{get_attr_type(name, module)} "#{name}". \
    Expected a #{inspect(type)}, got: #{inspect(value)}.

    Original expression: {{#{original}}}
    #{details}\
    """
  end

  defp get_attr_type(name, module) do
    cond do
      to_string(name) |> String.starts_with?(":") ->
        "directive"

      module ->
        "property"

      true ->
        "attribute"
    end
  end
end
