defmodule Surface.Compiler.EExEngine do
  @moduledoc """
  This module glues together surface's AST and Phoenix.LiveView.Engine to actually render an AST.

  It takes a list of Surface AST nodes, and processes them into a sequence of static raw html items and
  dynamic pieces. It then converts these into tokens which an EEx engine can understand (see EEx.Tokenizer
  for information on this). Finally, it passes these tokens into the engine sequentially in the same
  manner as EEx.Compiler.compile/2
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

  defp generate_buffer([expr | tail], buffer, state) do
    buffer = state.engine.handle_expr(buffer, "=", to_expression(expr, buffer, state))
    generate_buffer(tail, buffer, state)
  end

  defp to_expression(nodes, buffer, state)

  defp to_expression([node], buffer, state), do: to_expression(node, buffer, state)

  defp to_expression(nodes, buffer, state) when is_list(nodes) do
    children =
      for node <- nodes do
        to_expression(node, buffer, state)
      end

    {:__block__, [], children}
  end

  defp to_expression({:text, value}, _buffer, _state), do: {:safe, value}

  defp to_expression(%AST.AttributeExpr{value: expr}, _buffer, _state), do: expr

  defp to_expression(%AST.Interpolation{value: expr}, _buffer, _state), do: expr

  defp to_expression(%AST.Container{children: children}, buffer, state),
    do: to_expression(children, buffer, state)

  defp to_expression(
         %AST.Comprehension{generator: %AST.AttributeExpr{value: generator}, children: children},
         buffer,
         state
       ) do
    buffer = handle_nested_block(children, buffer, state)

    generator_expr = generator ++ [[do: buffer]]

    {:for, [generated: true], generator_expr}
  end

  defp to_expression(
         %AST.Conditional{condition: %AST.AttributeExpr{value: condition}, children: children},
         buffer,
         state
       ) do
    buffer = handle_nested_block(children, buffer, state)

    {:if, [generated: true], [condition, [do: buffer]]}
  end

  defp to_expression(
         %AST.Slot{
           name: name,
           props: %AST.Directive{value: %AST.AttributeExpr{value: props_expr}},
           default: default
         },
         buffer,
         state
       ) do
    default_value = to_expression(default, buffer, state)

    slot_name_expr = at_ref(name)

    slot_content_expr =
      if name == :default do
        quote generated: true do
          unquote(at_ref(:inner_content)).(unquote(props_expr))
        end
      else
        quote generated: true do
          for slot <- unquote(slot_name_expr) do
            slot.inner_content.(unquote(props_expr))
          end
        end
      end

    quote generated: true do
      if Enum.member?(unquote(at_ref(:__surface__)).provided_templates, unquote(name)) do
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
         buffer,
         state
       ) do
    defaults = Enum.map(module.__props__(), fn prop -> {prop.name, prop.opts[:default]} end)
    slots = Enum.map(module.__slots__(), fn slot -> {slot.name, []} end)

    props_values =
      for %AST.Attribute{name: name, type: type, value: value} <- props do
        {name, to_prop_expr(component_type, type, value)}
      end

    blocks =
      (templates.default || [])
      |> Enum.map(fn %AST.Template{
                       props: %AST.Directive{value: %AST.AttributeExpr{value: let}},
                       children: children
                     } ->
        block = handle_nested_block(children, buffer, state)
        values = Keyword.keys(let)
        # TODO: validate the let expression is actually what it should be
        # TODO: possibly translate this based on the slot :props value?
        variables = Keyword.values(let)

        quote do
          (fn unquote(variables) ->
             unquote(block)
           end).(unquote(values))
        end
      end)

    do_block =
      quote generated: true do
        fn -> unquote(blocks) end
      end

    assigns =
      (defaults ++
         slots ++
         props_values)
      |> Keyword.new()
      |> Enum.reject(fn {name, value} ->
        case module.__get_prop__(name) do
          nil -> true
          prop -> prop.opts[:reject_nil] && is_nil(value)
        end
      end)

    if component_type == Surface.LiveView do
      quote generated: true do
        Phoenix.LiveView.Helpers.live_render(
          unquote(at_ref(:socket)),
          unquote(module),
          unquote(assigns)
        )
      end
    else
      assigns =
        Keyword.put(
          assigns,
          :__surface__,
          quote generated: true do
            %{provided_templates: []}
          end
        )

      quote generated: true do
        Phoenix.LiveView.Helpers.live_component(
          unquote(at_ref(:socket)),
          unquote(module),
          Keyword.new(unquote(assigns)),
          do: unquote(do_block)
        )
      end
    end
  end

  defp handle_nested_block(block, buffer, state) do
    buffer = state.engine.handle_begin(buffer)

    buffer =
      Enum.reduce(block, buffer, fn
        {:text, chars}, buffer -> state.engine.handle_text(buffer, chars)
        expr, buffer -> state.engine.handle_expr(buffer, "=", to_expression(expr, buffer, state))
      end)

    state.engine.handle_end(buffer)
  end

  defp to_prop_expr(_, :boolean, [%AST.Text{value: value}]) do
    !!value
  end

  defp to_prop_expr(_, :boolean, [%AST.AttributeExpr{value: expr}]) do
    quote generated: true do
      !!unquote(expr)
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
    expr
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
      to_html_string(name, values),
      ~S("),
      to_html_attributes(attributes)
    ]
  end

  defp to_html_string(_name, []), do: []

  defp to_html_string(name, [%AST.Text{value: value} | elements]),
    do: [value | to_html_string(name, elements)]

  defp to_html_string(name, [%AST.AttributeExpr{value: value} = expr | elements]) do
    # TODO: is this the behaviour we want?

    value =
      if to_string(name) in Surface.Directive.Events.phx_events() do
        quote generated: true do
          Phoenix.HTML.html_escape(Surface.phx_event(unquote(to_string(name)), unquote(value)))
        end
      else
        quote generated: true do
          Phoenix.HTML.html_escape(Surface.attr_value(unquote(to_string(name)), unquote(value)))
        end
      end

    [%{expr | value: value} | to_html_string(name, elements)]
  end

  defp at_ref(name) do
    {:@, [generated: true], [{name, [generated: true], nil}]}
  end
end
