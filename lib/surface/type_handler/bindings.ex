defmodule Surface.TypeHandler.Bindings do
  @moduledoc false

  use Surface.TypeHandler

  @impl true
  def literal_to_ast_node(_type, _name, _value, _meta) do
    :error
  end

  @impl true
  def expr_to_quoted(_type, _name, [key], [as: as], _meta, _original)
      when is_atom(key) and is_atom(as) do
    {:ok, {key, as}}
  end

  @impl true
  def expr_to_quoted(_type, _name, [key], [], _meta, _original) when is_atom(key) do
    {:ok, {key, key}}
  end

  @impl true
  def expr_to_quoted(_type, _name, _clauses, _opts, _meta, _original) do
    {:error,
     "Expected a mapping from a slot prop to an assign, e.g. {{ :item }} or {{ :item, as: :user }}"}
  end
end
