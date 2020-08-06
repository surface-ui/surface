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
      depth: 0,
      context: []
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

  defp to_expression(%AST.Container{children: children} = container, buffer, state),
    do: to_expression(children, buffer, state) |> maybe_print_expression(container)

  defp to_expression(
         %AST.Comprehension{generator: %AST.AttributeExpr{value: generator}, children: children} =
           comprehension,
         buffer,
         state
       ) do
    buffer =
      handle_nested_block(children, buffer, %{
        state
        | depth: state.depth + 1,
          context: [:for | state.context]
      })

    generator_expr = generator ++ [[do: buffer]]

    {:for, [generated: true], generator_expr}
    |> maybe_print_expression(comprehension)
  end

  defp to_expression(
         %AST.Conditional{condition: %AST.AttributeExpr{value: condition}, children: children} =
           conditional,
         buffer,
         state
       ) do
    buffer =
      handle_nested_block(children, buffer, %{
        state
        | depth: state.depth + 1,
          context: [:if | state.context]
      })

    {:if, [generated: true], [condition, [do: buffer]]}
    |> maybe_print_expression(conditional)
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
    slot_content_expr =
      if name == :default do
        quote generated: true do
          unquote(at_ref(:inner_content)).(unquote(props_expr))
        end
      else
        slot_name_expr = at_ref(name)

        quote generated: true do
          # TODO: For now, we only handle the first since rendering multiple items requires using `:for` directly in the template.
          # Review this after we adding option `join`.
          Enum.at(unquote(slot_name_expr), 0).inner_content.(unquote(props_expr))
        end
      end

    default_value =
      handle_nested_block(default, buffer, %{
        state
        | depth: state.depth + 1,
          context: [:slot | state.context]
      })

    name_to_check = if name == :default, do: :__default__, else: name

    quote generated: true do
      if Enum.member?(unquote(at_ref(:__surface__)).provided_templates, unquote(name_to_check)) do
        unquote(slot_content_expr)
      else
        unquote(default_value)
      end
    end
  end

  defp to_expression(
         %AST.Component{
           module: module,
           type: Surface.LiveView,
           props: props
         } = component,
         _buffer,
         _state
       ) do
    props_expr =
      collect_component_props(module, props)
      |> Enum.reject(fn {_, value} -> is_nil(value) end)

    quote generated: true do
      live_render(
        unquote(at_ref(:socket)),
        unquote(module),
        unquote(props_expr)
      )
    end
    |> maybe_print_expression(component)
  end

  defp to_expression(
         %ast_type{
           module: module,
           props: props,
           templates: templates
         } = component,
         buffer,
         state
       )
       when ast_type in [AST.Component, AST.SlotableComponent] do
    props_expr = collect_component_props(module, props)

    # if we decide to provide the gets in init_context
    # we'll need to split these out
    context_assigns = fetch_context_assigns(module)

    {do_block, slot_meta, slot_props} = collect_slot_meta(component, templates, buffer, state)

    assigns_expr =
      if state.depth > 0 and Enum.member?(state.context, :template) do
        quote generated: true do
          ctx_assigns
        end
      else
        quote generated: true do
          var!(assigns)
        end
      end

    quote generated: true do
      live_component(
        unquote(at_ref(:socket)),
        unquote(module),
        Surface.build_assigns(
          unquote(assigns_expr),
          unquote(props_expr),
          unquote(context_assigns),
          unquote(slot_props),
          unquote(slot_meta),
          unquote(module)
        ),
        unquote(do_block)
      )
    end
    |> maybe_print_expression(component)
  end

  defp collect_component_props(module, attrs) do
    Enum.map(module.__props__(), fn %{name: prop_name, type: type, opts: prop_opts} ->
      value =
        case find_attribute_value(attrs, prop_name, nil) do
          nil -> prop_opts[:default]
          expr -> to_prop_expr(expr, type)
        end

      {prop_name, value}
    end)
  end

  defp fetch_context_assigns(module) do
    context_gets =
      module.__context_gets__()
      |> Enum.map(fn %{name: name, opts: opts} ->
        {opts[:from], {name, opts[:as] || name}}
      end)
      |> Enum.group_by(fn {from, _} -> from end, fn {_, opts} -> opts end)
      |> Keyword.new()

    context_sets_in_scope = [
      {module, Enum.map(module.__context_sets_in_scope__(), fn %{name: name} -> {name, name} end)}
    ]

    context_gets ++ context_sets_in_scope
  end

  defp collect_slot_meta(component, templates, buffer, state) do
    slot_info =
      templates
      |> Enum.map(fn {name, templates_for_slot} ->
        {if(name == :default, do: :__default__, else: name), Enum.count(templates_for_slot),
         handle_templates(component, templates_for_slot, buffer, %{
           state
           | context: [:template | state.context]
         })}
      end)

    do_block =
      slot_info
      |> Enum.map(fn {name, _size, infos} ->
        infos
        |> Enum.with_index()
        |> Enum.map(fn {{let, _, body}, index} ->
          quote generated: true do
            {unquote(name), unquote(index),
             {unquote({:%{}, [generated: true], let}), ctx_assigns}} ->
              unquote(body)
          end
        end)
      end)
      |> List.flatten()
      |> case do
        [] -> []
        block -> [do: block]
      end

    slot_props =
      for {name, _, infos} <- slot_info,
          not Enum.empty?(infos) do
        {name, Enum.map(infos, fn {_, props, _} -> {:%{}, [generated: true], props} end)}
      end

    slot_meta =
      for {name, size, _} <- slot_info do
        {name, {:%{}, [generated: true], [size: size]}}
      end

    {do_block, slot_meta, slot_props}
  end

  defp handle_nested_block(block, buffer, state) when is_list(block) do
    buffer = state.engine.handle_begin(buffer)

    buffer =
      Enum.reduce(block, buffer, fn
        {:text, chars}, buffer -> state.engine.handle_text(buffer, chars)
        expr, buffer -> state.engine.handle_expr(buffer, "=", to_expression(expr, buffer, state))
      end)

    state.engine.handle_end(buffer)
  end

  defp handle_nested_block(block, buffer, state) do
    buffer = state.engine.handle_begin(buffer)

    buffer = state.engine.handle_expr(buffer, "=", to_expression(block, buffer, state))
    state.engine.handle_end(buffer)
  end

  defp handle_templates(_component, [], _, _), do: []

  defp handle_templates(
         component,
         [
           %AST.Template{
             name: name,
             let: %AST.Directive{value: %AST.AttributeExpr{value: let}},
             children: children
           }
           | tail
         ],
         buffer,
         state
       ) do
    [
      {add_default_bindings(component, name, let), [],
       handle_nested_block(children, buffer, %{state | depth: state.depth + 1})}
      | handle_templates(component, tail, buffer, state)
    ]
  end

  defp handle_templates(
         component,
         [
           %AST.SlotableComponent{
             slot: name,
             module: module,
             let: %AST.Directive{value: %AST.AttributeExpr{value: let}},
             props: props,
             templates: %{default: default}
           }
           | tail
         ],
         buffer,
         state
       ) do
    template =
      case default do
        [] -> []
        [%AST.Template{children: children}] -> children
      end

    [
      {add_default_bindings(component, name, let), collect_component_props(module, props),
       handle_nested_block(template, buffer, %{state | depth: state.depth + 1})}
      | handle_templates(component, tail, buffer, state)
    ]
  end

  defp add_default_bindings(%{module: module, props: props}, name, let) do
    (module.__get_slot__(name)[:opts][:props] || [])
    |> Enum.reject(fn
      %{generator: nil} -> true
      %{name: name} -> Keyword.has_key?(let, name)
    end)
    |> Enum.map(fn %{generator: gen, name: name} ->
      case find_attribute_value(props, gen, nil) do
        [%AST.AttributeExpr{value: {binding, _}}] ->
          {name, binding}

        _ ->
          nil
      end
    end)
    |> Enum.reject(fn value -> value == nil end)
    |> Keyword.merge(let)
  end

  defp find_attribute_value(attrs, name, default)
  defp find_attribute_value([], _, default), do: default

  defp find_attribute_value([%AST.Attribute{name: attr_name, value: value} | _], name, _)
       when attr_name == name,
       do: value

  defp find_attribute_value([_ | tail], name, default),
    do: find_attribute_value(tail, name, default)

  defp to_prop_expr([%AST.Text{value: value}], :boolean) do
    !!value
  end

  defp to_prop_expr([%AST.AttributeExpr{value: expr}], :boolean) do
    quote generated: true do
      !!unquote(expr)
    end
  end

  defp to_prop_expr([%AST.AttributeExpr{value: {_, value}}], :list), do: value

  defp to_prop_expr([%{value: value}], :string), do: value

  defp to_prop_expr(values, :string) do
    list_expr =
      for %{value: value} <- values do
        value
      end

    quote generated: true do
      List.to_string(unquote(list_expr))
    end
  end

  defp to_prop_expr([%AST.Text{value: value}], _) do
    value
  end

  defp to_prop_expr([%AST.AttributeExpr{value: expr}], _) do
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

  defp to_dynamic_nested_html([%type{templates: templates_by_name} = component | nodes])
       when type in [AST.Component, AST.SlotableComponent] do
    templates_by_name =
      templates_by_name
      |> Enum.map(fn {name, templates} ->
        templates =
          Enum.map(templates, fn
            %AST.Template{children: children} = template ->
              %{template | children: to_token_sequence(children)}

            %AST.SlotableComponent{} = template ->
              [translated] = to_dynamic_nested_html([template])
              translated
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

  defp maybe_print_expression(expr, node) do
    if Map.has_key?(node, :debug) and Enum.member?(node.debug, :code) do
      IO.puts(">>> DEBUG(EXPRESSION): #{node.meta.file}:#{node.meta.line}")
      expr |> Macro.to_string() |> Code.format_string!(line_length: 120) |> IO.puts()
      IO.puts("<<<")
    end

    expr
  end
end
