defmodule Surface.TypeHandler.Generator do
  @moduledoc false

  use Surface.TypeHandler

  @impl true
  def expr_to_quoted(_type, _name, clauses, _opts, _meta, _original) do
    # TODO: Validate
    {:ok, clauses}
  end
end
