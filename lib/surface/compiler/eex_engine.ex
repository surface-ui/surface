defmodule Surface.Compiler.EExEngine do
  @moduledoc """
  This module glues together surface's AST and Phoenix.LiveView.Engine to actually render an AST.

  It takes a list of Surface AST nodes, and processes them into a sequence of static raw html items and
  dynamic pieces. It then converts these into tokens which an EEx engine can understand (see EEx.Tokenizer
  for information on this). Finally, it passes these tokens into the engine sequentially in the same
  manner as EEx.Compiler.compile/2
  """
  alias Surface.AST
  alias Surface.IOHelper

  # while this should technically work with other engines, the main use case is integration with Phoenix.LiveView.Engine
  @default_engine Phoenix.LiveView.Engine

  @spec translate(
          [Surface.AST.t()],
          nil | maybe_improper_list | map
        ) :: any
  def translate(nodes, opts \\ []) do
    state = %{
      engine: opts[:engine] || @default_engine,
      depth: 0,
      context: []
    }

    nodes
    |> to_token_sequence()
    |> generate_buffer(state.engine.init(opts), state)
    |> maybe_print_expression(
      opts[:debug],
      opts[:file] || "nofile",
      opts[:line] || 1
    )
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

  defp generate_buffer([%AST.Expr{} = expr | tail], buffer, state) do
    buffer = state.engine.handle_expr(buffer, "", to_expression(expr, buffer, state))
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

  defp to_expression(%AST.Expr{value: expr}, _buffer, _state) when is_list(expr),
    do: {:__block__, [], expr}

  defp to_expression(%AST.Expr{value: expr}, _buffer, _state), do: {:__block__, [], [expr]}

  defp to_expression(
         %AST.For{generator: %AST.AttributeExpr{value: generator}, children: children} = comprehension,
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
         %AST.If{
           condition: %AST.AttributeExpr{value: condition},
           children: if_children,
           else: else_children
         } = conditional,
         buffer,
         state
       ) do
    if_buffer =
      handle_nested_block(if_children, buffer, %{
        state
        | depth: state.depth + 1,
          context: [:if | state.context]
      })

    else_buffer =
      handle_nested_block(else_children, buffer, %{
        state
        | depth: state.depth + 1,
          context: [:if | state.context]
      })

    {:if, [generated: true], [condition, [do: if_buffer, else: else_buffer]]}
    |> maybe_print_expression(conditional)
  end

  defp to_expression(%AST.Block{name: "case"} = block, buffer, state) do
    %AST.Block{expression: case_expr, sub_blocks: sub_blocks} = block

    state = %{state | depth: state.depth + 1, context: [:case | state.context]}

    match_blocks =
      Enum.flat_map(sub_blocks, fn %AST.SubBlock{children: children, expression: expr} ->
        match_body = handle_nested_block(children, buffer, state)

        quote do
          unquote(expr) -> unquote(match_body)
        end
      end)

    quote do
      case unquote(case_expr) do
        unquote(match_blocks)
      end
    end
    |> maybe_print_expression(block)
  end

  defp to_expression(
         %AST.Slot{
           name: slot_name,
           index: index_ast,
           args: args_expr,
           default: default
         },
         buffer,
         state
       ) do
    slot_index =
      case index_ast do
        %AST.AttributeExpr{value: expr} -> expr
        %AST.Literal{value: value} -> value
      end

    context_expr =
      if is_child_component?(state) do
        quote generated: true do
          Map.merge(@__context__, the_context)
        end
      else
        quote do
          @__context__
        end
      end

    # TODO: map names somehow?
    slot_content_expr =
      quote generated: true do
        if @inner_block do
          render_block(
            @inner_block,
            {
              unquote(slot_name),
              unquote(slot_index),
              Map.new(unquote(args_expr)),
              unquote(context_expr)
            }
          )
        end
      end

    default_value =
      handle_nested_block(default, buffer, %{
        state
        | depth: state.depth + 1,
          context: [:slot | state.context]
      })

    quote generated: true do
      if Enum.member?(@__surface__.provided_templates, unquote(slot_name)) do
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
        @socket,
        unquote(module),
        unquote(props_expr)
      )
    end
    |> maybe_print_expression(component)
  end

  defp to_expression(
         %ast_type{
           module: module,
           type: component_type,
           props: props,
           dynamic_props: dynamic_props,
           templates: templates,
           meta: meta
         } = component,
         buffer,
         state
       )
       when ast_type in [AST.Component, AST.SlotableComponent] do
    props_expr = collect_component_props(module, props)

    dynamic_props_expr = handle_dynamic_props(dynamic_props)

    if module.__use_context__?() do
      Module.put_attribute(meta.caller.module, :use_context?, true)
    end

    context_expr =
      cond do
        module.__slots__() == [] and not module.__use_context__?() ->
          quote generated: true do
            %{}
          end

        is_child_component?(state) ->
          quote generated: true do
            Map.merge(@__context__ || %{}, the_context)
          end

        true ->
          quote generated: true do
            @__context__ || %{}
          end
      end

    {do_block, slot_meta, slot_props} = collect_slot_meta(component, templates, buffer, state)

    if component_type == Surface.LiveComponent do
      quote generated: true do
        live_component(
          unquote(module),
          Surface.build_assigns(
            unquote(context_expr),
            unquote(props_expr),
            unquote(dynamic_props_expr),
            unquote(slot_props),
            unquote(slot_meta),
            unquote(module),
            unquote(meta.node_alias)
          ),
          unquote(do_block)
        )
      end
    else
      quote generated: true do
        component(
          &unquote(module).render/1,
          Surface.build_assigns(
            unquote(context_expr),
            unquote(props_expr),
            unquote(dynamic_props_expr),
            unquote(slot_props),
            unquote(slot_meta),
            unquote(module),
            unquote(meta.node_alias)
          ),
          unquote(do_block)
        )
      end
    end
    |> maybe_print_expression(component)
  end

  defp handle_dynamic_props(nil), do: []

  defp handle_dynamic_props(%AST.DynamicAttribute{expr: %AST.AttributeExpr{value: expr}}) do
    expr
  end

  defp collect_component_props(module, attrs) do
    {props, props_acc} =
      Enum.reduce(attrs, {[], %{}}, fn attr, {props, props_acc} ->
        %AST.Attribute{name: prop_name, type: type, type_opts: type_opts, value: expr} = attr

        cond do
          !module.__validate_prop__(prop_name) ->
            {props, props_acc}

          type_opts[:accumulate] ->
            current_value = props_acc[prop_name] || []
            updated_value = [to_prop_expr(expr, type) | current_value]
            {props, Map.put(props_acc, prop_name, updated_value)}

          true ->
            {[{prop_name, to_prop_expr(expr, type)} | props], props_acc}
        end
      end)

    Enum.reverse(props) ++ Enum.map(props_acc, fn {k, v} -> {k, Enum.reverse(v)} end)
  end

  defp collect_slot_meta(component, templates, buffer, state) do
    slot_info =
      templates
      |> Enum.map(fn {name, templates_for_slot} ->
        state = %{state | context: [:template | state.context]}

        nested_templates = handle_templates(component, templates_for_slot, buffer, state)

        {name, Enum.count(templates_for_slot), nested_templates}
      end)

    do_block =
      slot_info
      |> Enum.map(fn {name, _size, infos} ->
        infos
        |> Enum.with_index()
        |> Enum.map(fn {{let, _, body}, index} ->
          quote generated: true do
            {
              unquote(name),
              unquote(index),
              unquote({:%{}, [generated: true], let}),
              the_context
            } ->
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
      for {name, size, _infos} <- slot_info do
        meta_value =
          quote generated: true do
            %{size: unquote(size)}
          end

        {name, meta_value}
      end

    {do_block, slot_meta, slot_props}
  end

  defp handle_nested_block(block, buffer, state) when is_list(block) do
    buffer = state.engine.handle_begin(buffer)

    buffer =
      Enum.reduce(block, buffer, fn
        {:text, chars}, buffer ->
          state.engine.handle_text(buffer, chars)

        %AST.Expr{} = expr, buffer ->
          state.engine.handle_expr(buffer, "", to_expression(expr, buffer, state))

        expr, buffer ->
          state.engine.handle_expr(buffer, "=", to_expression(expr, buffer, state))
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
             let: let,
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

  defp handle_templates(component, [slotable | tail], buffer, state) do
    %AST.SlotableComponent{
      slot: name,
      module: module,
      let: let,
      props: props,
      templates: %{default: default}
    } = slotable

    template =
      cond do
        !module.__renderless__?() ->
          [
            %AST.Component{
              module: module,
              type: slotable.type,
              props: props,
              dynamic_props: nil,
              directives: [],
              templates: slotable.templates,
              meta: slotable.meta,
              debug: slotable.debug
            }
          ]

        Enum.empty?(default) ->
          []

        true ->
          %AST.Template{children: children} = List.first(default)
          children
      end

    props = collect_component_props(module, props)
    default_props = Surface.default_props(module)

    [
      {add_default_bindings(component, name, let), Keyword.merge(default_props, props),
       handle_nested_block(template, buffer, %{state | depth: state.depth + 1})}
      | handle_templates(component, tail, buffer, state)
    ]
  end

  defp add_default_bindings(%{module: module, props: props}, name, let) do
    (module.__get_slot__(name)[:opts][:args] || [])
    |> Enum.reject(fn
      %{generator: nil} -> true
      %{name: name} -> Keyword.has_key?(let, name)
    end)
    |> Enum.map(fn %{generator: gen, name: name} ->
      case find_attribute_value(props, gen, nil) do
        %AST.AttributeExpr{value: {binding, _}} ->
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

  defp to_prop_expr(%AST.AttributeExpr{value: value, meta: meta}, type) do
    Surface.TypeHandler.update_prop_expr(type, value, meta)
  end

  defp to_prop_expr(%AST.Literal{value: value}, _) do
    value
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

  defp combine_static_portions([node | values], {static_acc, node_acc}) do
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

  defp to_dynamic_nested_html([%AST.Literal{value: text} | nodes]) do
    [text | to_dynamic_nested_html(nodes)]
  end

  defp to_dynamic_nested_html([
         %AST.Container{
           children: children,
           meta: %AST.Meta{
             module: mod,
             line: line
           }
         }
         | nodes
       ])
       when not is_nil(mod) do
    [require_expr(mod, line), to_dynamic_nested_html(children) | to_dynamic_nested_html(nodes)]
  end

  defp to_dynamic_nested_html([%AST.Container{children: children} | nodes]) do
    [to_dynamic_nested_html(children) | to_dynamic_nested_html(nodes)]
  end

  defp to_dynamic_nested_html([%AST.Slot{default: default} = slot | nodes]) do
    [%{slot | default: to_token_sequence(default)} | to_dynamic_nested_html(nodes)]
  end

  defp to_dynamic_nested_html([
         %AST.If{children: if_children, else: else_children} = conditional | nodes
       ]) do
    [
      %{
        conditional
        | children: to_token_sequence(if_children),
          else: to_token_sequence(else_children)
      },
      to_dynamic_nested_html(nodes)
    ]
  end

  defp to_dynamic_nested_html([%AST.For{children: children} = comprehension | nodes]) do
    [%{comprehension | children: to_token_sequence(children)}, to_dynamic_nested_html(nodes)]
  end

  defp to_dynamic_nested_html([%AST.Block{sub_blocks: sub_blocks} = block | nodes]) do
    [%{block | sub_blocks: to_token_sequence(sub_blocks)} | to_dynamic_nested_html(nodes)]
  end

  defp to_dynamic_nested_html([%AST.SubBlock{children: children} = sub_block | nodes]) do
    [%{sub_block | children: to_token_sequence(children)} | to_dynamic_nested_html(nodes)]
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

  defp to_dynamic_nested_html([
         %type{module: mod, templates: templates_by_name} = component | nodes
       ])
       when type in [AST.Component, AST.SlotableComponent] do
    {requires, templates_by_name} =
      Enum.reduce(templates_by_name, {[], %{}}, fn {name, templates}, {requires_acc, by_name} ->
        {requires, templates} =
          Enum.reduce(templates, {requires_acc, []}, fn
            %AST.Template{children: children} = template, {requires, templates} ->
              {requires, [%{template | children: to_token_sequence(children)} | templates]}

            %AST.SlotableComponent{} = template, {requires, templates} ->
              [cmp, nested, translated] = to_dynamic_nested_html([template])

              {[cmp, nested | requires], [translated | templates]}
          end)

        {requires, Map.put(by_name, name, Enum.reverse(templates))}
      end)

    [
      require_expr(mod, component.meta.line),
      requires,
      %{component | templates: templates_by_name} | to_dynamic_nested_html(nodes)
    ]
  end

  defp to_dynamic_nested_html([
         %AST.Error{message: message, meta: %AST.Meta{module: mod, line: line}} | nodes
       ])
       when not is_nil(mod),
       do: [
         require_expr(mod, line),
         ~S(<span style="color: red; border: 2px solid red; padding: 3px"> Error: ),
         escape_message(message),
         ~S(</span>) | to_dynamic_nested_html(nodes)
       ]

  defp to_dynamic_nested_html([%AST.Error{message: message} | nodes]),
    do: [
      ~S(<span style="color: red; border: 2px solid red; padding: 3px"> Error: ),
      escape_message(message),
      ~S(</span>) | to_dynamic_nested_html(nodes)
    ]

  defp to_dynamic_nested_html([%AST.Interpolation{} = value | nodes]),
    do: [value | to_dynamic_nested_html(nodes)]

  defp to_dynamic_nested_html([%AST.Expr{} = value | nodes]),
    do: [value | to_dynamic_nested_html(nodes)]

  defp to_html_attributes([]), do: []

  defp to_html_attributes([
         %AST.Attribute{name: name, type: :string, value: %AST.Literal{value: value}}
         | attributes
       ])
       when is_binary(value) do
    [[" ", to_string(name), "=", ~S("), value, ~S(")], to_html_attributes(attributes)]
  end

  defp to_html_attributes([
         %AST.Attribute{name: name, type: type, value: %AST.Literal{value: value}}
         | attributes
       ]) do
    runtime_value = Surface.TypeHandler.expr_to_value!(type, name, [value], [], nil, value)
    [Surface.TypeHandler.attr_to_html!(type, name, runtime_value), to_html_attributes(attributes)]
  end

  defp to_html_attributes([
         %AST.DynamicAttribute{
           expr: %AST.AttributeExpr{constant?: true} = expr
         }
         | attributes
       ]) do
    try do
      {expr_value, _} = Code.eval_quoted(expr.value)

      new_attrs =
        Enum.map(expr_value, fn {name, {type, value}} ->
          evaluate_literal_attribute(name, type, value, expr.meta)
        end)

      [new_attrs | to_html_attributes(attributes)]
    rescue
      e in RuntimeError ->
        IOHelper.compile_error(e.message, expr.meta.file, expr.meta.line)
    end
  end

  defp to_html_attributes([
         %AST.DynamicAttribute{expr: %AST.AttributeExpr{value: expr_value} = expr} | attributes
       ]) do
    value =
      quote generated: true do
        for {name, {type, value}} <- unquote(expr_value) do
          Phoenix.HTML.raw(Surface.TypeHandler.attr_to_html!(type, name, value))
        end
      end

    [%{expr | value: value} | to_html_attributes(attributes)]
  end

  defp to_html_attributes([
         %AST.Attribute{value: %AST.AttributeExpr{constant?: true} = expr} = attr
         | attributes
       ]) do
    try do
      {expr_value, _} = Code.eval_quoted(expr.value)

      value = evaluate_literal_attribute(attr.name, attr.type, expr_value, attr.meta)

      [value | to_html_attributes(attributes)]
    rescue
      e in RuntimeError ->
        IOHelper.compile_error(e.message, expr.meta.file, expr.meta.line)
    end
  end

  defp to_html_attributes([
         %AST.Attribute{
           name: name,
           type: type,
           value: %AST.AttributeExpr{value: expr_value} = expr
         }
         | attributes
       ]) do
    value =
      quote generated: true do
        Phoenix.HTML.raw(Surface.TypeHandler.attr_to_html!(unquote(type), unquote(name), unquote(expr_value)))
      end

    [%{expr | value: value} | to_html_attributes(attributes)]
  end

  defp maybe_print_expression(expr, node) do
    maybe_print_expression(
      expr,
      Map.has_key?(node, :debug) and Enum.member?(node.debug, :code),
      node.meta.file,
      node.meta.line
    )
  end

  defp evaluate_literal_attribute(name, type, value, meta) do
    case Surface.TypeHandler.attr_to_html(type, name, value) do
      {:ok, attr} -> attr
      {:error, message} -> IOHelper.compile_error(message, meta.file, meta.line)
    end
  end

  defp maybe_print_expression(expr, print?, file, line) do
    if print? do
      IO.puts(">>> DEBUG(EXPRESSION): #{file}:#{line}")
      expr |> Macro.to_string() |> Code.format_string!(line_length: 120) |> IO.puts()
      IO.puts("<<<")
    end

    expr
  end

  defp require_expr(module, line) do
    %AST.Expr{
      value:
        quote generated: true, line: line do
          require unquote(module)
        end,
      meta: %AST.Meta{}
    }
  end

  defp is_child_component?(state) do
    state.depth > 0 and Enum.member?(state.context, :template)
  end

  defp escape_message(message) do
    {:safe, message_iodata} = Phoenix.HTML.html_escape(message)
    IO.iodata_to_binary(message_iodata)
  end
end
