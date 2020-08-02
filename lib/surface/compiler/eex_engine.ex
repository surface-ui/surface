defmodule Surface.Compiler.EExEngine do
  @moduledoc """
  This module glues together surface's AST and Phoenix.LiveView.Engine to actually render an AST.

  It takes a list of Surface AST nodes, and processes them into a sequence of static raw html items and
  dynamic pieces. It then converts these into tokens which an EEx engine can understand (see EEx.Tokenizer
  for information on this). Finally, it passes these tokens into the engine sequentially in the same
  manner as EEx.Compiler.compile/2

  Expressions within surface templates are equivalent to <%= ... %> expressions within EEx, other variants such as
  <% ... %>, <%# ... %>, <%| ... %>, and <%/ ... %> are not supported. This is because surface expressions must always
  be complete statements. This also limits the EEx.Engine api that we rely on, as :start_expr, :middle_expr, and :end_expr
  tokens will never be generated.
  """
  alias Surface.AST

  # while this should technically work with other engines, the main use case is integration with Phoenix.LiveView.Engine
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

  defp to_expression(nodes, escape \\ false)

  defp to_expression(nodes, escape) when is_list(nodes) do
    children =
      for node <- nodes do
        to_expression(node, escape)
      end

    {:__block__, [], children}
  end

  defp to_expression({:text, value}, _), do: {:safe, value}

  defp to_expression(%AST.AttributeExpr{value: expr}, _), do: expr

  defp to_expression(%AST.Interpolation{value: expr}, true) do
    ## is this something we always want to do?
    quote generated: true do
      Phoenix.HTML.html_escape(unquote(expr))
    end
  end

  defp to_expression(%AST.Interpolation{value: expr}, false), do: expr

  defp to_expression(%AST.Container{children: children}, _), do: to_expression(children)

  defp to_expression(%AST.Comprehension{generator: generator, children: children}, _) do
    {:__block__, [], children_expr} = to_expression(children, true)

    generator_expr = to_expression(generator, false) ++ [[do: {:__block__, [], [children_expr]}]]

    {:for, [generated: true], generator_expr}
  end

  defp to_expression(%AST.Conditional{condition: condition, children: children}, _) do
    children_expr = to_expression(children, true)
    condition_expr = to_expression(condition, false)

    {:if, [generated: true], [condition_expr, [do: children_expr]]}
  end

  defp to_expression(
         %AST.Slot{
           name: name,
           props: %AST.Directive{value: %AST.AttributeExpr{value: props_expr}},
           default: default
         },
         _escape
       ) do
    default_value = to_expression(default, true)

    # This is an expression which is equivalent to @#{name}
    # I couldn't figure out a good way to accomplish this using quote, and
    # I didn't think using Code.string_to_quoted!() made sense because the
    # AST is fairly minimal
    slot_name_expr = {:@, [generated: true], [{name, [generated: true], nil}]}

    slot_content_expr =
      if name == :default do
        quote generated: true do
          @inner_content.(unquote(props_expr))
        end
      else
        quote generated: true do
          for slot <- unquote(slot_name_expr) do
            slot.inner_content.(unquote(props_expr))
          end
        end
      end

    quote generated: true do
      if Enum.member?(@__surface__.provided_templates, unquote(name)) do
        unquote(slot_content_expr)
      else
        unquote(default_value)
      end
    end
  end

  defp to_expression(
         %AST.Component{
           module: module,
           type: component_type,
           props: props,
           templates: templates,
           meta: _meta
         },
         _escape?
       ) do
    defaults = Enum.map(module.__props__(), fn prop -> {prop.name, prop.opts[:default]} end)
    slots = Enum.map(module.__slots__(), fn slot -> {slot.name, []} end)

    props_values =
      for %AST.Attribute{name: name, type: type, value: value} <- props do
        {name, to_prop_expr(component_type, type, value)}
      end

    assigns =
      Keyword.new(
        defaults ++
          slots ++
          props_values ++
          [
            __surface__:
              quote generated: true do
                %{provided_templates: []}
              end
          ]
      )

    if component_type == Surface.LiveView do
      quote generated: true do
        Phoenix.LiveView.Helpers.live_render(@socket, unquote(module), unquote(assigns))
      end
    else
      quote generated: true do
        Phoenix.LiveView.Helpers.live_component(@socket, unquote(module), unquote(assigns))
      end
    end
  end

  defp to_prop_expr(_, :boolean, [%AST.Text{value: value}]) do
    !!value
  end

  defp to_prop_expr(_, :boolean, [%AST.AttributeExpr{value: expr}]) do
    quote generated: true do
      !!unquote(expr)
    end
  end

  defp to_prop_expr(Surface.LiveComponent, :event, [%{value: value}]) do
    quote generated: true do
      Surface.event_value(nil, unquote(value), @myself)
    end
  end

  defp to_prop_expr(_, :event, [%{value: value}]) do
    quote generated: true do
      Surface.event_value(nil, unquote(value), nil)
    end
  end

  defp to_prop_expr(_, :string, values) do
    list_expr =
      for %{value: value} <- values do
        value
      end

    quote generated: true do
      List.to_string(unquote(list_expr))
    end
  end

  defp to_prop_expr(_, _, [%AST.Text{value: value}]) do
    value
  end

  defp to_prop_expr(_, _, [%AST.AttributeExpr{value: expr}]) do
    quote generated: true do
      unquote(expr)
    end
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
         %AST.DynamicAttribute{expr: %AST.AttributeExpr{value: value_expr} = expr} | attributes
       ]) do
    value =
      quote generated: true do
        for {name, {type, value}} <- unquote(value_expr) do
          case type do
            :boolean ->
              if value do
                [" ", to_string(name)]
              else
                []
              end

            _ ->
              [
                " ",
                to_string(name),
                unquote(Phoenix.HTML.raw("=\"")),
                value,
                unquote(Phoenix.HTML.raw("\""))
              ]
          end
        end
      end

    [%{expr | value: value} | to_html_attributes(attributes)]
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
        if unquote(value) do
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
