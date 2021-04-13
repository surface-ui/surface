defmodule Surface.TypeHandler.Hook do
  @moduledoc false

  use Surface.TypeHandler

  @impl true
  def literal_to_ast_node(type, name, value, meta) when is_binary(value) do
    {:ok,
     %Surface.AST.AttributeExpr{
       original: value,
       value: Surface.TypeHandler.expr_to_quoted!(Macro.to_string(value), name, type, meta),
       meta: meta
     }}
  end

  def literal_to_ast_node(_type, _name, _value, _meta) do
    :error
  end

  @impl true
  def expr_to_quoted(type, name, clauses, opts, meta, original) do
    quoted_expr =
      quote generated: true do
        Surface.TypeHandler.expr_to_value!(
          unquote(type),
          unquote(name),
          unquote(clauses),
          Keyword.put_new(unquote(opts), :from, __MODULE__),
          unquote(meta.module),
          unquote(original)
        )
      end

    {:ok, quoted_expr}
  end

  @impl true
  def expr_to_value([value], _) when value in [nil, false] do
    {:ok, value}
  end

  def expr_to_value(clauses, opts) do
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

          <div :hook={{ "Card", from: CardList }}>
        """

        {:error, clauses ++ opts, message}
    end
  end
end
