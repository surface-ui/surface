defmodule Surface.TypeHandler.Event do
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
    caller_cid = Surface.AST.Meta.quoted_caller_cid(meta)

    with {:ok, quoted_expr} <- super(type, name, clauses, opts, meta, original) do
      updated_quoted_expr =
        quote generated: true do
          unquote(__MODULE__).maybe_update_target(unquote(quoted_expr), unquote(caller_cid))
        end

      {:ok, updated_quoted_expr}
    end
  end

  @impl true
  def expr_to_value([nil], []) do
    {:ok, nil}
  end

  def expr_to_value([%{name: _, target: _} = event], []) do
    {:ok, event}
  end

  def expr_to_value([name], opts) when is_atom(name) or is_binary(name) do
    {:ok, %{name: to_string(name), target: Keyword.get(opts, :target)}}
  end

  def expr_to_value(clauses, opts) do
    {:error, {clauses, opts}}
  end

  def maybe_update_target(%{target: nil} = event, nil) do
    %{event | target: :live_view}
  end

  def maybe_update_target(%{target: nil} = event, cid) do
    %{event | target: cid}
  end

  def maybe_update_target(event, _cid) do
    event
  end
end
