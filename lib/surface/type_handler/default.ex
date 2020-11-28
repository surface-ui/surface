defmodule Surface.TypeHandler.Default do
  @moduledoc false

  use Surface.TypeHandler

  @impl true
  def literal_to_ast_node(_type, _name, value, _meta) do
    {:ok, %Surface.AST.Literal{value: value}}
  end

  @impl true
  def expr_to_quoted(type, name, clauses, opts, meta, original) do
    quoted_expr =
      quote generated: true do
        Surface.TypeHandler.expr_to_value!(
          unquote(type),
          unquote(name),
          unquote(clauses),
          unquote(opts),
          unquote(meta.module),
          unquote(original)
        )
      end

    {:ok, quoted_expr}
  end

  @impl true
  def expr_to_value([value], []) do
    {:ok, value}
  end

  def expr_to_value([], opts) do
    {:ok, opts}
  end

  def expr_to_value(clauses, opts) do
    {:error, clauses ++ opts}
  end

  @impl true
  def value_to_html(_name, {:safe, _} = value) do
    {:ok, value}
  end

  def value_to_html(name, value) do
    if String.Chars.impl_for(value) do
      {:ok, value}
    else
      message = """
      invalid value for attribute "#{name}". Expected a type that implements \
      the String.Chars protocol (e.g. string, boolean, integer, atom, ...), \
      got: #{inspect(value)}\
      """

      {:error, message}
    end
  end

  @impl true
  def value_to_opts(_name, value) do
    {:ok, value}
  end

  @impl true
  def update_prop_expr(value, _meta) do
    value
  end
end
