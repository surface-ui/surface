defmodule Surface.Formatter.Phases.FinalNewline do
  @moduledoc """
             Add a newline after all of the nodes if one was present on the original input
             """ && false

  @behaviour Surface.Formatter.Phase

  # special case for empty heredocs
  def run([:indent], _opts), do: []

  def run(nodes, opts) do
    if Keyword.get(opts, :trailing_newline, false) do
      nodes ++ [:newline]
    else
      nodes
    end
  end
end
