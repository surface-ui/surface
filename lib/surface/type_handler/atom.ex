defmodule Surface.TypeHandler.Atom do
  @moduledoc false

  use Surface.TypeHandler

  alias Surface.IOHelper

  @impl true
  def literal_to_ast_node(_type, name, value, meta) when is_binary(value) do
    message = """
    automatic conversion of string literals into atoms is deprecated \
    and will be removed in v0.5.0.

    Hint: replace `#{name}="#{value}"` with `#{name}={{ :#{value} }}`
    """

    IOHelper.warn(message, meta.caller, fn _ -> meta.line end)
    {:ok, %Surface.AST.Literal{value: String.to_atom(value)}}
  end

  def literal_to_ast_node(_name, _type, _value, _meta) do
    :error
  end

  @impl true
  def expr_to_value([value], []) when is_atom(value) do
    {:ok, value}
  end

  def expr_to_value(clauses, opts) do
    {:error, clauses ++ opts}
  end
end
