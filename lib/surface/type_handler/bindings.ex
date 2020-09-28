defmodule Surface.TypeHandler.Bindings do
  @moduledoc false

  use Surface.TypeHandler

  @impl true
  def literal_to_ast_node(_type, _name, _value, _meta) do
    :error
  end

  @impl true
  def expr_to_quoted(_type, _name, _clauses, opts, _meta, _original) do
    if opts != [] and Keyword.keyword?(opts) do
      {:ok, opts}
    else
      {:error, "Expected a keyword list of bindings, e.g. {{ item: user, info: info }}"}
    end
  end
end
