defmodule Surface.TypeHandler.Bindings do
  @moduledoc false

  use Surface.TypeHandler
  alias Surface.TypeHandler.TypesHelper

  @impl true
  def literal_to_ast_node(_type, _name, _value, _meta) do
    :error
  end

  @impl true
  def expr_to_quoted(_type, _name, clauses, bindings, meta, _original) do
    # Don't validate if it's a function component as it accepts anything
    if meta.function_component? do
      case clauses do
        [clause] -> {:ok, clause}
        _ -> {:ok, clauses ++ bindings}
      end
    else
      if clauses == [] and TypesHelper.is_bindings?(bindings) do
        {:ok, bindings}
      else
        {:error, "Expected a keyword list of bindings, e.g. {item: user, info: info}"}
      end
    end
  end
end
