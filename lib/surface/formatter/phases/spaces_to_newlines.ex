defmodule Surface.Formatter.Phases.SpacesToNewlines do
  @moduledoc """
             In a variety of scenarios, converts :space nodes to :newline nodes.

             (Below, "element" means an HTML element or a Surface component.)

             1. If an element contains other elements as children, surround it with newlines.
             1. If there is a space after an opening tag or before a closing tag, convert it to a newline.
             1. If there is a closing tag on its own line, ensure there's a newline before the next sibling node.
             """ && false

  @behaviour Surface.Formatter.Phase
  alias Surface.{Formatter, Formatter.Phase}

  def run(nodes, _opts) do
    nodes
    |> ensure_newlines_surrounding_elements_with_element_children()
    |> convert_spaces_to_newlines_around_edge_children()
    |> move_siblings_after_lone_closing_tag_to_new_line()
  end

  # If an element has an element as a child, ensure it's surrounded by newlines, not spaces
  defp ensure_newlines_surrounding_elements_with_element_children(nodes, accumulated \\ [])

  defp ensure_newlines_surrounding_elements_with_element_children(
         [:space, {_, _, children, _} = element, :space | rest],
         accumulated
       ) do
    whitespace =
      if Enum.any?(children, &Formatter.is_element?/1) do
        :newline
      else
        :space
      end

    ensure_newlines_surrounding_elements_with_element_children(
      rest,
      accumulated ++ [whitespace, element, whitespace]
    )
  end

  defp ensure_newlines_surrounding_elements_with_element_children(
         [{_, _, children, _} = element, :space | rest],
         accumulated
       ) do
    whitespace =
      if Enum.any?(children, &Formatter.is_element?/1) do
        :newline
      else
        :space
      end

    ensure_newlines_surrounding_elements_with_element_children(
      rest,
      accumulated ++ [element, whitespace]
    )
  end

  defp ensure_newlines_surrounding_elements_with_element_children([node | rest], accumulated) do
    ensure_newlines_surrounding_elements_with_element_children(rest, accumulated ++ [node])
  end

  defp ensure_newlines_surrounding_elements_with_element_children([], accumulated) do
    Phase.transform_element_children(
      accumulated,
      &ensure_newlines_surrounding_elements_with_element_children/1
    )
  end

  # If there is a space before the first child / after the last, convert it to a newline
  defp convert_spaces_to_newlines_around_edge_children(nodes) do
    # If there is a space before the first child, and it's an element, convert it to a newline
    nodes =
      case nodes do
        [:space, element | rest] ->
          [:newline, element | rest]

        _ ->
          nodes
      end

    # If there is a space before the first child, and it's an element, convert it to a newline
    nodes =
      case Enum.reverse(nodes) do
        [:space, _element | _rest] ->
          Enum.slice(nodes, 0..-2//1) ++ [:newline]

        _ ->
          nodes
      end

    nodes
    |> Phase.transform_element_children(&convert_spaces_to_newlines_around_edge_children/1)
  end

  # Basically makes sure that this
  #
  # <p>
  #   Foo
  # </p> <p>Hello</p>
  #
  # turns into this
  #
  # <p>
  #   Foo
  # </p>
  # <p>Hello</p>
  defp move_siblings_after_lone_closing_tag_to_new_line(nodes, accumulated \\ [])

  defp move_siblings_after_lone_closing_tag_to_new_line(
         [{_, _, children, _} = element, :space | rest],
         accumulated
       ) do
    if Enum.any?(children, &(&1 == :newline)) do
      move_siblings_after_lone_closing_tag_to_new_line(
        rest,
        accumulated ++ [element, :newline]
      )
    else
      move_siblings_after_lone_closing_tag_to_new_line(
        rest,
        accumulated ++ [element, :space]
      )
    end
  end

  defp move_siblings_after_lone_closing_tag_to_new_line([node | rest], accumulated) do
    move_siblings_after_lone_closing_tag_to_new_line(rest, accumulated ++ [node])
  end

  defp move_siblings_after_lone_closing_tag_to_new_line([], accumulated) do
    Phase.transform_element_children(
      accumulated,
      &move_siblings_after_lone_closing_tag_to_new_line/1
    )
  end
end
