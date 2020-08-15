defmodule Surface.TypeHandler.Boolean do
  @moduledoc false

  use Surface.TypeHandler

  @impl true
  def expr_to_value([value], []) do
    {:ok, !!value}
  end
end
