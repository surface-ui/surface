defmodule Surface.Formatter.Phases.FinalNewline do
  @moduledoc "Add a newline after all of the nodes"

  @behaviour Surface.Formatter.Phase

  def run(nodes, _opts) do
    nodes ++ [:newline]
  end
end
