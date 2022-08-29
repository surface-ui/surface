defmodule Surface.Formatter.Phases.Indent do
  @moduledoc """
             Adds indentation nodes (`:indent` and `:indent_one_less`) where appropriate.

             `Surface.Formatter.Render.node/2` is responsible for adding the appropriate
             level of indentation. It keeps track of the indentation level based on how
             "nested" a node is. While running Formatter Phases, it's not necessary to
             keep track of that detail.

             `:indent_one_less` exists to notate the indentation that should occur before
             a closing tag, which is one less than its children.

             Relies on `Newlines` phase, which collapses :newline nodes to at most 2 in a row.
             """ && false

  @behaviour Surface.Formatter.Phase
  alias Surface.Formatter.Phase

  def run(nodes, _opts) do
    # Add initial indent on start of first line
    indent([:indent | nodes])
  end

  defp indent(nodes) do
    # Deeply recurse through nodes and add indentation before newlines
    nodes
    |> add_indentation()
    |> Phase.transform_element_children(&indent/1)
  end

  def add_indentation(nodes, accumulated \\ [])

  def add_indentation([:newline, :newline | rest], accumulated) do
    # Two newlines in a row; don't add indentation on the empty line
    add_indentation(rest, accumulated ++ [:newline, :newline, :indent])
  end

  def add_indentation([:newline], accumulated) do
    # The last child is a newline; add indentation for closing tag
    add_indentation([], accumulated ++ [:newline, :indent_one_less])
  end

  def add_indentation([:newline | rest], accumulated) do
    # Indent before the next child
    add_indentation(rest, accumulated ++ [:newline, :indent])
  end

  def add_indentation([], accumulated) do
    accumulated
  end

  def add_indentation([node | rest], accumulated) do
    add_indentation(rest, accumulated ++ [node])
  end
end
