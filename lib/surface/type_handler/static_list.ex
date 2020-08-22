defmodule Surface.TypeHandler.StaticList do
  @moduledoc false

  use Surface.TypeHandler

  @impl true
  def expr_to_quoted(_type, _name, [clause], [], _meta, _original) when is_list(clause) do
    {:ok, clause}
  end

  def expr_to_quoted(_type, _name, _clauses, _opts, _meta, _original) do
    :error
  end
end
