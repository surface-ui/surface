defmodule Surface.Formatter.Phases.Newlines do
  @moduledoc """
             Standardizes usage of newlines.

             - Prevents more than 1 empty line in a row.
             - Prevents an empty line separating an opening/closing tag from the contents inside.
             """ && false

  @behaviour Surface.Formatter.Phase
  alias Surface.Formatter.Phase

  def run(nodes, _opts) do
    nodes
    |> collapse_newlines()
    |> prevent_empty_line_at_beginning()
    |> prevent_empty_line_at_end()
  end

  defp collapse_newlines(nodes) do
    nodes
    |> Enum.chunk_by(&(&1 == :newline))
    |> Enum.map(fn
      [:newline, :newline | _] -> [:newline, :newline]
      nodes -> nodes
    end)
    |> Enum.flat_map(&Function.identity/1)
    |> Phase.transform_element_children(&collapse_newlines/1)
  end

  defp prevent_empty_line_at_beginning(nodes) do
    nodes
    |> case do
      [:newline, :newline | rest] -> [:newline | rest]
      _ -> nodes
    end
    |> Phase.transform_element_children(&prevent_empty_line_at_beginning/1)
  end

  defp prevent_empty_line_at_end(nodes) do
    nodes
    |> Enum.slice(-2..-1//1)
    |> case do
      [:newline, :newline] -> Enum.slice(nodes, 0..-2//1)
      _ -> nodes
    end
    |> Phase.transform_element_children(&prevent_empty_line_at_end/1)
  end
end
