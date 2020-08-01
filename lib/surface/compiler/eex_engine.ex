defmodule Surface.Compiler.EExEngine do
  alias Surface.AST

  @default_engine Phoenix.LiveView.Engine

  def translate(nodes, opts \\ []) do
    state = %{
      engine: opts[:engine] || @default_engine,
      file: opts[:file] || "nofile",
      line: opts[:line] || 1,
      quoted: [],
      start_line: nil,
      start_column: nil,
      parser_options: Code.get_compiler_option(:parser_options)
    }

    nodes
    |> to_token_sequence()
    |> to_eex_tokens()
    |> generate_buffer(state.engine.init(opts), state)
  end

  defp to_token_sequence(nodes) do
    nodes
    |> to_dynamic_nested_html()
    |> List.flatten()
    |> combine_static_portions()
  end

  defp generate_buffer([], buffer, state) do
    state.engine.handle_body(buffer)
  end

  defp generate_buffer([{:text, chars} | tail], buffer, state) do
    buffer = state.engine.handle_text(buffer, chars)
    generate_buffer(tail, buffer, state)
  end

  defp generate_buffer([{:expr, mark, expr} | tail], buffer, state) do
    buffer = state.engine.handle_expr(buffer, mark, expr)
    generate_buffer(tail, buffer, state)
  end

  @doc """
  This converts surface AST nodes into something similar to EEx tokens. There
  are some differences
  """
  defp to_eex_tokens([]), do: []

  defp to_eex_tokens([{:text, head} | tail]) do
    [{:text, head} | to_eex_tokens(tail)]
  end

  defp to_eex_tokens([%AST.AttributeExpr{} = expr | tail]) do
    [{:expr, "=", to_expression(expr)} | to_eex_tokens(tail)]
  end

  defp to_eex_tokens([%AST.Interpolation{} = expr | tail]) do
    [{:expr, "=", to_expression(expr)} | to_eex_tokens(tail)]
  end

  defp to_eex_tokens([%AST.Conditional{} = expr | tail]) do
    [{:expr, "=", to_expression(expr)} | to_eex_tokens(tail)]
  end

  defp to_eex_tokens([%AST.Comprehension{} = expr | tail]) do
    [{:expr, "=", to_expression(expr)} | to_eex_tokens(tail)]
  end

  defp to_eex_tokens([%AST.Component{} = expr | tail]) do
    [{:expr, "=", to_expression(expr)} | to_eex_tokens(tail)]
  end

  defp to_eex_tokens([%AST.Slot{} = expr | tail]) do
    [{:expr, "=", to_expression(expr)} | to_eex_tokens(tail)]
  end

  defp to_expression([node]) do
    to_expression(node)
  end

  defp to_expression(nodes) when is_list(nodes) do
    children =
      for node <- nodes do
        to_expression(node)
      end

    {:__block__, [], children}
  end

  defp to_expression({:text, value}), do: Phoenix.HTML.raw(value)
  defp to_expression(%AST.AttributeExpr{value: expr}), do: expr
  defp to_expression(%AST.Interpolation{value: expr}), do: expr
  defp to_expression(%AST.Container{children: children}), do: to_expression(children)

  defp to_expression(%AST.Comprehension{generator: generator, children: children}) do
    children_expr = to_expression(children)
    generator_expr = to_expression(generator)

    quote generated: true do
      for unquote(generator_expr) do
        unquote(children_expr)
      end
    end
  end

  defp to_expression(%AST.Conditional{condition: condition, children: children}) do
    children_expr = to_expression(children)
    condition_expr = to_expression(condition)

    quote generated: true do
      if unquote(condition_expr) do
        unquote(children_expr)
      end
    end
  end

  defp to_expression(%AST.Slot{default: default}) do
    # TODO
    to_expression(default)
  end

  defp to_expression(%AST.Component{}) do
    Phoenix.HTML.raw("<span>This is still TODO</span>")
  end

  defp combine_static_portions(nodes, accumulators \\ {[], []})
  defp combine_static_portions([], {[], node_acc}), do: Enum.reverse(node_acc)

  defp combine_static_portions([], {static_acc, node_acc}),
    do:
      combine_static_portions(
        [],
        {[], [{:text, join_string_list(static_acc)} | node_acc]}
      )

  defp combine_static_portions([str | values], {static_acc, node_acc}) when is_binary(str),
    do: combine_static_portions(values, {[str | static_acc], node_acc})

  defp combine_static_portions([node | values], {static_acc, node_acc}) when is_struct(node) do
    node_acc =
      case static_acc do
        [] -> node_acc
        list -> [{:text, join_string_list(list)} | node_acc]
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

  defp to_dynamic_nested_html([%AST.Container{children: children} | nodes]) do
    [to_dynamic_nested_html(children) | to_dynamic_nested_html(nodes)]
  end

  defp to_dynamic_nested_html([%AST.Slot{default: default} = slot | nodes]) do
    [%{slot | default: to_token_sequence(default)} | to_dynamic_nested_html(nodes)]
  end

  defp to_dynamic_nested_html([%AST.Conditional{children: children} = conditional | nodes]) do
    [%{conditional | children: to_token_sequence(children)}, to_dynamic_nested_html(nodes)]
  end

  defp to_dynamic_nested_html([%AST.Comprehension{children: children} = comprehension | nodes]) do
    [%{comprehension | children: to_token_sequence(children)}, to_dynamic_nested_html(nodes)]
  end

  defp to_dynamic_nested_html([
         %AST.VoidTag{
           element: element,
           attributes: attributes
         }
         | nodes
       ]) do
    [
      "<",
      element,
      to_html_attributes(attributes),
      ">",
      to_dynamic_nested_html(nodes)
    ]
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

  defp to_dynamic_nested_html([%AST.Component{templates: templates_by_name} = component | nodes]) do
    templates_by_name =
      templates_by_name
      |> Enum.map(fn {name, templates} ->
        templates =
          Enum.map(templates, fn %AST.Template{children: children} = template ->
            %{template | children: to_token_sequence(children)}
          end)

        {name, templates}
      end)
      |> Enum.into(%{})

    [%{component | templates: templates_by_name} | to_dynamic_nested_html(nodes)]
  end

  defp to_dynamic_nested_html([%AST.Error{message: message} | nodes]),
    do: [
      ~S(<span style="color: red; border: 2px solid red; padding: 3px"> Error: ),
      message,
      ~S(</span>) | to_dynamic_nested_html(nodes)
    ]

  defp to_dynamic_nested_html([%AST.Interpolation{} = value | nodes]),
    do: [value | to_dynamic_nested_html(nodes)]

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
