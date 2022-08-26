defmodule Surface.TypeHandler.Hook do
  @moduledoc false

  use Surface.TypeHandler

  @impl true
  def literal_to_ast_node(type, name, value, meta) when is_binary(value) do
    {:ok,
     Surface.AST.AttributeExpr.new(
       Surface.TypeHandler.expr_to_quoted!(Macro.to_string(value), name, type, meta),
       value,
       meta
     )}
  end

  @impl true
  def literal_to_ast_node(type, name, true, meta) do
    {:ok,
     Surface.AST.AttributeExpr.new(
       Surface.TypeHandler.expr_to_quoted!(Macro.to_string("default"), name, type, meta),
       true,
       meta
     )}
  end

  def literal_to_ast_node(_type, _name, _value, _meta) do
    :error
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
          Keyword.put_new(unquote(opts), :from, __MODULE__),
          unquote(meta.module),
          unquote(original),
          unquote(ctx)
        )
      end

    {:ok, quoted_expr}
  end

  @impl true
  def expr_to_value([value], _, _ctx) when value in [nil, false] do
    {:ok, value}
  end

  def expr_to_value(clauses, opts, _ctx) do
    case {clauses, opts} do
      {[hook], [from: mod]} when is_binary(hook) and is_atom(mod) ->
        {:ok, {hook, mod}}

      _ ->
        message = """
        Hint: the hook is the name of the exported JS hook object with an optional `from: origin`,
        where `origin` is the component module defining the hook, default is `__MODULE__`.

        Example:

          <div :hook="Card">

        Example with options:

          <div :hook={"Card", from: CardList}>
        """

        {:error, clauses ++ opts, message}
    end
  end
end
