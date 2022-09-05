defmodule Surface.TypeHandler.Default do
  @moduledoc false

  use Surface.TypeHandler

  @impl true
  def literal_to_ast_node(_type, _name, value, _meta) do
    {:ok, %Surface.AST.Literal{value: value}}
  end

  @impl true
  def expr_to_quoted(type, name, clauses, opts, meta, original) do
    ctx = Surface.AST.Meta.quoted_caller_context(meta)

    quoted_expr =
      quote do
        Surface.TypeHandler.expr_to_value!(
          unquote(type),
          unquote(name),
          unquote(clauses),
          unquote(opts),
          unquote(meta.module),
          unquote(original),
          unquote(ctx)
        )
      end

    {:ok, quoted_expr}
  end

  @impl true
  def expr_to_value([value], [], _ctx) do
    {:ok, value}
  end

  def expr_to_value([], opts, _ctx) do
    {:ok, opts}
  end

  def expr_to_value(clauses, opts, _ctx) do
    {:error, clauses ++ opts}
  end

  @impl true
  def value_to_html(_name, {:safe, _} = value) do
    {:ok, value}
  end

  def value_to_html(_name, %Phoenix.LiveView.JS{} = value) do
    {:ok, Surface.TypeHandler.Event.normalize_value(value)}
  end

  def value_to_html(_name, %{name: _, target: _} = value) do
    {:ok, Surface.TypeHandler.Event.normalize_value(value)}
  end

  # TODO: If we had a %Surface.Event{} struct, we could implement the Phoenix.HTML.Safe
  # protocol and get rid of this and let phoenix raise the default runtime error for other
  # types. We could also adopt %Phoenix.LiveView.JS{} which already implements it.
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
  def value_to_opts(:value, "") do
    {:ok, :value, ""}
  end

  @impl true
  def value_to_opts(_name, value) do
    {:ok, value}
  end
end
