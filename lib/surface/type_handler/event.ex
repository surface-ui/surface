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
  def expr_to_value([nil], [], _ctx) do
    {:ok, nil}
  end

  def expr_to_value([%{name: _, target: _} = event], [], %{cid: cid}) do
    {:ok, maybe_update_target(event, cid)}
  end

  def expr_to_value([%JS{} = js], [], %{cid: cid}) do
    {:ok, maybe_update_target(js, cid)}
  end

  def expr_to_value([name], opts, %{cid: cid}) when is_atom(name) or is_binary(name) do
    value = %{name: to_string(name), target: Keyword.get(opts, :target)}
    value = maybe_update_target(value, cid)
    {:ok, value}
  end

  def expr_to_value(clauses, opts, %{cid: _}) do
    {:error, {clauses, opts}}
  end

  def expr_to_value(_clauses, _opts, ctx) do
    raise "the event type requires the caller context to have an cid, got: #{inspect(ctx)}"
  end

  defp maybe_update_target(%{target: nil} = event, nil) do
    %{event | target: :live_view}
  end

  defp maybe_update_target(%{target: nil} = event, cid) do
    %{event | target: cid}
  end

  defp maybe_update_target(%JS{ops: ops} = event, cid) do
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

  defp maybe_update_target(event, _cid) do
    event
  end

  @doc false
  def normalize_value(%JS{ops: ops} = value) do
    updated_ops =
      Enum.map(ops, fn
        ["push", %{target: :live_view} = options] ->
          ["push", Map.delete(options, :target)]

        op ->
          op
      end)

    %JS{value | ops: updated_ops}
  end

  def normalize_value(%{name: name, target: :live_view}) do
    name
  end

  def normalize_value(%{name: name, target: target}) do
    JS.push(name, target: target)
  end
end
