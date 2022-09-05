defmodule Surface.TypeHandler.ContextGet do
  @moduledoc false

  use Surface.TypeHandler
  alias Surface.TypeHandler.TypesHelper

  @impl true
  def literal_to_ast_node(_type, _name, _value, _meta) do
    :error
  end

  @impl true
  def expr_to_quoted(_type, _name, clauses, bindings, _meta, _original) do
    with {:ok, scope} <- TypesHelper.extract_scope(clauses),
         true <- TypesHelper.is_bindings?(bindings) do
      {:ok, {:__context_get__, scope, bindings}}
    else
      _ ->
        message = """
        expected a scope module (optional) along with a keyword list of bindings, \
        e.g. {Form, form: form} or {field: my_field}\
        """

        {:error, message}
    end
  end
end
