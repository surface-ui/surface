defmodule Surface.Compiler.Renderer do
  alias Surface.AST

  def render(nodes) do
    nodes
    |> to_dynamic_nested_html()
    |> List.flatten()
    |> combine_static_portions()
  end

  defp combine_static_portions(nodes, accumulators \\ {[], []})
  defp combine_static_portions([], {[], node_acc}), do: Enum.reverse(node_acc)

  defp combine_static_portions([], {static_acc, node_acc}),
    do:
      combine_static_portions(
        [],
        {[], [join_string_list(static_acc) | node_acc]}
      )

  defp combine_static_portions([str | values], {static_acc, node_acc}) when is_binary(str),
    do: combine_static_portions(values, {[str | static_acc], node_acc})

  defp combine_static_portions([node | values], {static_acc, node_acc}) when is_struct(node) do
    node_acc =
      case static_acc do
        [] -> node_acc
        list -> [join_string_list(list) | node_acc]
      end

    combine_static_portions(values, {[], [node | node_acc]})
  end

  defp join_string_list(list) do
    list
    |> Enum.reverse()
    |> IO.iodata_to_binary()
  end

  defp to_dynamic_nested_html([]), do: []

  defp to_dynamic_nested_html([%AST.Text{value: text} | nodes]) do
    [text | to_dynamic_nested_html(nodes)]
  end

  defp to_dynamic_nested_html([
         %AST.Tag{
           element: element,
           attributes: attributes,
           children: children
         }
         | nodes
       ]) do
    [
      "<",
      element,
      to_html_attributes(attributes),
      ">",
      to_dynamic_nested_html(children),
      "</",
      element,
      ">",
      to_dynamic_nested_html(nodes)
    ]
  end

  defp to_dynamic_nested_html([%AST.Component{} = component | nodes]),
    do: [component | nodes]

  defp to_dynamic_nested_html([%AST.Error{message: message} | nodes]),
    do: [
      ~S(<span style="color: red; border: 2px solid red; padding: 3px"> Error: ),
      message,
      ~S(</span>) | nodes
    ]

  defp to_dynamic_nested_html([%AST.Interpolation{} = value | nodes]),
    do: [value | nodes]

  defp to_html_attributes([]), do: []

  defp to_html_attributes([
         %AST.Attribute{name: name, type: :boolean, value: [%AST.Text{value: value}]}
         | attributes
       ]) do
    if value do
      [
        ~S( ),
        to_string(name),
        to_html_attributes(attributes)
      ]
    else
      to_html_attributes(attributes)
    end
  end

  defp to_html_attributes([
         %AST.Attribute{
           name: name,
           type: :boolean,
           value: [%AST.AttributeExpr{value: value} = expr]
         }
         | attributes
       ]) do
    attribute_name = to_string(name)

    conditional =
      quote generated: true do
        result = unquote(value)

        if result do
          [~S( ), unquote(attribute_name)]
        end
      end

    [%{expr | value: conditional} | to_html_attributes(attributes)]
  end

  defp to_html_attributes([
         %AST.Attribute{name: name, value: values}
         | attributes
       ]) do
    [
      ~S( ),
      to_string(name),
      ~S(="),
      to_html_string(values),
      ~S("),
      to_html_attributes(attributes)
    ]
  end

  defp to_html_string([]), do: []

  defp to_html_string([%AST.Text{value: value} | elements]),
    do: [value | to_html_string(elements)]

  defp to_html_string([%AST.AttributeExpr{} = expr | elements]) do
    # TODO: escape the result of the expression?
    [expr | to_html_string(elements)]
  end
end
