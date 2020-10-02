defmodule Surface.TypeHandler.Bindings do
  @moduledoc false

  use Surface.TypeHandler
  alias Surface.TypeHandler.TypesHelper

  @impl true
  def literal_to_ast_node(_type, _name, _value, _meta) do
    :error
  end

  @impl true
  def expr_to_quoted(_type, _name, clauses, bindings, _meta, _original) do
    if clauses == [] and TypesHelper.is_bindings?(bindings) do
      {:ok, bindings}
    else
      {:error, "Expected a keyword list of bindings, e.g. {{ item: user, info: info }}"}
    end
  end
end
