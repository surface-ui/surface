defmodule Surface.TypeHandler.StaticList do
  @moduledoc false

  use Surface.TypeHandler

  @impl true
  def validate_expr([clause], [], _module) when not is_list(clause) do
    :error
  end

  def validate_expr(_clauses, _opts, _module) do
    :ok
  end

  @impl true
  def expr_to_quoted(_type, _attribute_name, [clause], [], _meta, _original) do
    clause
  end

  def expr_to_quoted(_type, _attribute_name, clauses, opts, _meta, _original) do
    clauses ++ opts
  end
end
