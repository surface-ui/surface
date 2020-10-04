defmodule Surface.TypeHandler.ContextPut do
  @moduledoc false

  use Surface.TypeHandler

  alias Surface.TypeHandler.TypesHelper

  @impl true
  def literal_to_ast_node(_type, _name, _value, _meta) do
    :error
  end

  @impl true
  def expr_to_quoted(_type, _name, clauses, values, _meta, _original) do
    with {:ok, scope} <- TypesHelper.extract_scope(clauses),
         [_ | _] <- values do
      {:ok, {scope, values}}
    else
      _ ->
        message = """
        expected a scope module (optional) along with a keyword list of values, \
        e.g. {{ MyModule, field: @value, other: "other" }} or {{ field: @value }}\
        """

        {:error, message}
    end
  end
end
