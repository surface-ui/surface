defmodule Surface.TypeHandler.Event do
  @moduledoc false

  use Surface.TypeHandler

  @impl true
  def expr_to_value([nil], []) do
    {:ok, nil}
  end

  def expr_to_value([%{name: _, target: _} = event], []) do
    {:ok, event}
  end

  def expr_to_value([[name, {:target, target}]], [])
      when is_binary(name) and (is_binary(target) or is_atom(target)) do
    {:ok, %{name: name, target: target}}
  end

  def expr_to_value([name], opts) when is_atom(name) or is_binary(name) do
    {:ok, %{name: name, target: Keyword.get(opts, :target)}}
  end

  def expr_to_value(clauses, opts) do
    {:error, {clauses, opts}}
  end

  @impl true
  def update_prop_expr(value, meta) do
    caller_cid = Surface.AST.Meta.quoted_caller_cid(meta)

    quote generated: true do
      unquote(__MODULE__).maybe_update_target(unquote(value), unquote(caller_cid))
    end
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
