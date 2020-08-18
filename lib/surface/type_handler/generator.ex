defmodule Surface.TypeHandler.Generator do
  @moduledoc false

  use Surface.TypeHandler

  @impl true
  def validate_expr(_clauses, _opts, _module) do
    # TODO
    :ok
  end

  @impl true
  def expr_to_quoted(_type, _attribute_name, clauses, _opts, _module, _original) do
    clauses
  end
end
