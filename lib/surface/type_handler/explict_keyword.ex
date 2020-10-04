defmodule Surface.TypeHandler.ExplicitKeyword do
  @moduledoc false

  use Surface.TypeHandler

  @impl true
  def literal_to_ast_node(_type, _name, _value, _meta) do
    :error
  end

  @impl true
  def expr_to_quoted(_type, _name, [], values, _meta, _original) do
    if values != [] and Keyword.keyword?(values) do
      {:ok, values}
    else
      message = "expected a a explicit keyword list of values"
      {:error, message}
    end
  end
end
