defmodule Surface.TypeHandler.Event do
  @moduledoc false

  use Surface.TypeHandler

  alias Phoenix.LiveView.JS
  alias Phoenix.LiveComponent.CID

  @impl true
  def literal_to_ast_node(type, name, value, meta) when is_binary(value) do
    {:ok,
     Surface.AST.AttributeExpr.new(
       Surface.TypeHandler.expr_to_quoted!(Macro.to_string(value), name, type, meta),
       value,
       meta
     )}
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

  def expr_to_value([%JS{} = js], []) do
    {:ok, js}
  end

  def expr_to_value([name], opts) when is_atom(name) or is_binary(name) do
    {:ok, %{name: to_string(name), target: Keyword.get(opts, :target)}}
  end

  def expr_to_value(clauses, opts) do
    {:error, {clauses, opts}}
  end

  @impl true
  def value_to_html(_name, %JS{ops: ops} = value) do
    updated_ops =
      Enum.map(ops, fn
        ["push", %{target: :live_view} = options] ->
          ["push", Map.delete(options, :target)]

        op ->
          op
      end)

    {:ok, %JS{value | ops: updated_ops}}
  end

  def value_to_html(_name, %{name: name, target: :live_view}) do
    {:ok, name}
  end

  def value_to_html(_name, %{name: name, target: target}) do
    {:ok, JS.push(name, target: target)}
  end

  def value_to_html(name, value) do
    Surface.TypeHandler.Default.value_to_html(name, value)
  end

  def maybe_update_target(%{target: nil} = event, nil) do
    %{event | target: :live_view}
  end

  def maybe_update_target(%{target: nil} = event, cid) do
    %{event | target: cid}
  end

  def maybe_update_target(%JS{ops: ops} = event, cid) do
    updated_ops =
      Enum.map(ops, fn
        ["push", options] when not is_map_key(options, :target) ->
          target =
            case cid do
              %CID{cid: target} -> target
              _ -> :live_view
            end

          ["push", Map.put(options, :target, target)]

        op ->
          op
      end)

    %JS{event | ops: updated_ops}
  end

  def maybe_update_target(event, _cid) do
    event
  end
end
