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
  alias Surface.Components.Context

  # while this should technically work with other engines, the main use case is integration with Phoenix.LiveView.Engine
  @default_engine Phoenix.LiveView.Engine

  @string_types [:string, :css_class]

  @spec translate(
          [Surface.AST.t()],
          nil | maybe_improper_list | map
        ) :: any
  def translate(nodes, opts \\ []) do
    state = %{
      engine: opts[:engine] || @default_engine,
      depth: 0,
      context_vars: %{count: 0, changed: []},
      scope: []
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
    state.engine.handle_body(buffer, root: true)
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

  defp to_expression({:safe, value}, _buffer, _state), do: {:safe, value}
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
          scope: [:for | state.scope]
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
          scope: [:if | state.scope]
      })

    else_buffer =
      handle_nested_block(else_children, buffer, %{
        state
        | depth: state.depth + 1,
          scope: [:if | state.scope]
      })

    {:if, [generated: true], [condition, [do: if_buffer, else: else_buffer]]}
    |> maybe_print_expression(conditional)
  end

  defp to_expression(%AST.Block{name: "case"} = block, buffer, state) do
    %AST.Block{expression: case_expr, sub_blocks: sub_blocks} = block

    state = %{state | depth: state.depth + 1, scope: [:case | state.scope]}

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
           name: provided_name,
           as: slot_as,
           index: index_ast,
           for: slot_for_ast,
           args: args_expr,
           default: default,
           meta: meta
         },
         buffer,
         state
       ) do
    slot_index =
      case index_ast do
        %AST.AttributeExpr{value: expr} -> expr
        %AST.Literal{value: value} -> value
      end

    slot_for =
      case slot_for_ast do
        %AST.AttributeExpr{value: expr} -> expr
        %AST.Literal{value: value} -> value
        _ -> nil
      end

    parent_context_var = context_name(state.context_vars.count - 1, meta.caller)

    context_expr =
      if is_child_component?(state) do
        quote generated: true do
          unquote(parent_context_var)
        end
      else
        quote do
          %{}
        end
      end

    slot_value =
      if slot_for do
        quote do
          unquote(slot_for)
        end
      else
        slot_name = slot_as || provided_name
        slot_assign = {:@, [], [{slot_name, [], nil}]}

        quote do
          Enum.at(List.wrap(unquote(slot_assign)), unquote(slot_index))
        end
      end

    # TODO: map names somehow?
    slot_content_expr =
      quote generated: true do
        Phoenix.LiveView.Helpers.render_slot(
          unquote(slot_value),
          {
            Map.new(unquote(args_expr)),
            unquote(context_expr)
          }
        )
      end

    fallback_value =
      handle_nested_block(default, buffer, %{
        state
        | depth: state.depth + 1,
          scope: [:slot | state.scope]
      })

    quote generated: true do
      if unquote(slot_value) do
        unquote(slot_content_expr)
      else
        unquote(fallback_value)
      end
    end
  end

  # Dynamic component
  defp to_expression(%AST.FunctionComponent{type: :dynamic} = component, buffer, state) do
    %AST.FunctionComponent{
      module: %AST.AttributeExpr{value: module_expr},
      fun: fun,
      props: props,
      meta: meta
    } = component

    fun_expr =
      case fun do
        nil -> :render
        %AST.AttributeExpr{value: expr} -> expr
      end

    {props_expr, dynamic_props_expr} = build_props_expressions(nil, component)
    {context_expr, context_var, state} = process_context(nil, nil, props, meta.caller, state)
    slot_props = build_slot_props(component, buffer, state, context_var)
    slot_props_map = {:%{}, [generated: true], slot_props}
    ctx = Surface.AST.Meta.quoted_caller_context(meta)

    quote generated: true do
      Phoenix.LiveView.Helpers.component(
        &apply(unquote(module_expr), unquote(fun_expr), [&1]),
        Map.merge(
          Surface.build_dynamic_assigns(
            unquote(context_expr),
            unquote(props_expr),
            unquote(dynamic_props_expr),
            unquote(module_expr),
            unquote(meta.node_alias),
            unquote(ctx)
          ),
          unquote(slot_props_map)
        )
      )
    end
    |> maybe_print_expression(component)
  end

  # Local function component
  defp to_expression(%AST.FunctionComponent{type: :local} = component, buffer, state) do
    %AST.FunctionComponent{module: module, fun: fun, props: props, meta: meta} = component

    {props_expr, dynamic_props_expr} = build_props_expressions(nil, component)
    {context_expr, context_var, state} = process_context(module, fun, props, meta.caller, state)
    slot_props = build_slot_props(component, buffer, state, context_var)
    slot_props_map = {:%{}, [generated: true], slot_props}
    ctx = Surface.AST.Meta.quoted_caller_context(meta)

    quote generated: true do
      Phoenix.LiveView.Helpers.component(
        &(unquote(Macro.var(fun, __MODULE__)) / 1),
        Map.merge(
          Surface.build_assigns(
            unquote(context_expr),
            unquote(props_expr),
            unquote(dynamic_props_expr),
            nil,
            unquote(meta.node_alias),
            unquote(ctx)
          ),
          unquote(slot_props_map)
        )
      )
    end
    |> maybe_print_expression(component)
  end

  # Remote function component
  defp to_expression(%AST.FunctionComponent{type: :remote} = component, buffer, state) do
    %AST.FunctionComponent{module: module, fun: fun, props: props, meta: meta} = component

    {props_expr, dynamic_props_expr} = build_props_expressions(nil, component)
    {context_expr, context_var, state} = process_context(module, fun, props, meta.caller, state)
    slot_props = build_slot_props(component, buffer, state, context_var)
    slot_props_map = {:%{}, [generated: true], slot_props}
    ctx = Surface.AST.Meta.quoted_caller_context(meta)

    # For now, we can only retrieve props and slots information from module components,
    # not function components, so if we're dealing with dynamic or recursive module components,
    # we pass the module, otherwise, we pass `nil`.
    module_for_build_assigns = if fun == :render, do: module

    quote generated: true do
      Phoenix.LiveView.Helpers.component(
        &(unquote(module).unquote(fun) / 1),
        Map.merge(
          Surface.build_assigns(
            unquote(context_expr),
            unquote(props_expr),
            unquote(dynamic_props_expr),
            unquote(module_for_build_assigns),
            unquote(meta.node_alias),
            unquote(ctx)
          ),
          unquote(slot_props_map)
        )
      )
    end
    |> maybe_print_expression(component)
  end

  # Module stateless component
  defp to_expression(%AST.Component{type: Surface.Component} = component, buffer, state) do
    %AST.Component{module: module, props: props, meta: meta} = component

    {props_expr, dynamic_props_expr} = build_props_expressions(module, component)
    {context_expr, context_var, state} = process_context(module, :render, props, meta.caller, state)
    slot_props = build_slot_props(component, buffer, state, context_var)
    slot_props_map = {:%{}, [generated: true], slot_props}
    ctx = Surface.AST.Meta.quoted_caller_context(meta)

    quote generated: true do
      Phoenix.LiveView.Helpers.component(
        &unquote(module).render/1,
        Map.merge(
          Surface.build_assigns(
            unquote(context_expr),
            unquote(props_expr),
            unquote(dynamic_props_expr),
            unquote(module),
            unquote(meta.node_alias),
            unquote(ctx)
          ),
          unquote(slot_props_map)
        )
      )
    end
    |> maybe_print_expression(component)
  end

  # Slotable component
  defp to_expression(%AST.SlotableComponent{} = component, buffer, state) do
    %AST.SlotableComponent{module: module, props: props, meta: meta} = component

    {props_expr, dynamic_props_expr} = build_props_expressions(module, component)
    {context_expr, context_var, state} = process_context(module, :render, props, meta.caller, state)
    slot_props = build_slot_props(component, buffer, state, context_var)
    slot_props_map = {:%{}, [generated: true], slot_props}
    ctx = Surface.AST.Meta.quoted_caller_context(meta)

    quote generated: true do
      Phoenix.LiveView.Helpers.component(
        &unquote(module).render/1,
        Map.merge(
          Surface.build_assigns(
            unquote(context_expr),
            unquote(props_expr),
            unquote(dynamic_props_expr),
            unquote(module),
            unquote(meta.node_alias),
            unquote(ctx)
          ),
          unquote(slot_props_map)
        )
      )
    end
    |> maybe_print_expression(component)
  end

  # Live component
  defp to_expression(%AST.Component{type: Surface.LiveComponent} = component, buffer, state) do
    %AST.Component{module: module, props: props, meta: meta} = component

    {props_expr, dynamic_props_expr} = build_props_expressions(module, component)
    {context_expr, context_var, state} = process_context(module, :render, props, meta.caller, state)
    slot_props = build_slot_props(component, buffer, state, context_var)
    slot_props_map = {:%{}, [generated: true], [{:module, module} | slot_props]}
    ctx = Surface.AST.Meta.quoted_caller_context(meta)

    quote generated: true do
      Phoenix.LiveView.Helpers.component(
        &Phoenix.LiveView.Helpers.live_component/1,
        Map.merge(
          Surface.build_assigns(
            unquote(context_expr),
            unquote(props_expr),
            unquote(dynamic_props_expr),
            unquote(module),
            unquote(meta.node_alias),
            unquote(ctx)
          ),
          unquote(slot_props_map)
        )
      )
    end
    |> maybe_print_expression(component)
  end

  # Dynamic live component
  defp to_expression(%AST.Component{type: :dynamic_live} = component, buffer, state) do
    %AST.Component{
      module: %AST.AttributeExpr{value: module_expr},
      props: props,
      meta: meta
    } = component

    {props_expr, dynamic_props_expr} = build_props_expressions(nil, component)
    {context_expr, context_var, state} = process_context(nil, :render, props, meta.caller, state)
    slot_props = build_slot_props(component, buffer, state, context_var)
    slot_props_map = {:%{}, [generated: true], [{:module, module_expr} | slot_props]}
    ctx = Surface.AST.Meta.quoted_caller_context(meta)

    quote generated: true do
      Phoenix.LiveView.Helpers.component(
        &Phoenix.LiveView.Helpers.live_component/1,
        Map.merge(
          Surface.build_dynamic_assigns(
            unquote(context_expr),
            unquote(props_expr),
            unquote(dynamic_props_expr),
            unquote(module_expr),
            unquote(meta.node_alias),
            unquote(ctx)
          ),
          unquote(slot_props_map)
        )
      )
    end
    |> maybe_print_expression(component)
  end

  # LiveView
  defp to_expression(%AST.Component{type: Surface.LiveView} = component, _buffer, _state) do
    %AST.Component{module: module, props: props} = component

    props_expr =
      collect_component_props(module, props)
      |> Enum.reject(fn {_, value} -> is_nil(value) end)

    quote generated: true do
      live_render(@socket, unquote(module), unquote(props_expr))
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
        %AST.Attribute{root: root, value: expr} = attr

        {prop_name, type, type_opts} =
          with true <- root,
               root_prop when not is_nil(root_prop) <- Enum.find(module.__props__(), & &1.opts[:root]) do
            {root_prop.name, root_prop.type, root_prop.opts}
          else
            _ -> {attr.name, attr.type, attr.type_opts}
          end

        cond do
          module && !module.__validate_prop__(prop_name) ->
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

  # Function component
  defp build_slot_props(%AST.FunctionComponent{fun: fun} = component, buffer, state, _context_var)
       when fun != nil do
    slot_info =
      component.slot_entries
      |> Enum.map(fn {name, slot_entries} ->
        state = %{state | scope: [:slot_entry | state.scope]}

        nested_slot_entries = handle_slot_entries(component, slot_entries, buffer, state)

        {name, nested_slot_entries}
      end)

    case slot_info do
      [{:default, [{let, _, body}]}] ->
        block =
          if let == [] do
            quote generated: true do
              _ ->
                unquote(body)
            end
          else
            quote generated: true do
              unquote(let) ->
                unquote(body)
            end
          end

        ast =
          quote do
            Phoenix.LiveView.Helpers.inner_block(:inner_block, do: unquote(block))
          end

        props = [__slot__: :inner_block, inner_block: ast]

        [inner_block: {:%{}, [generated: true], props}]

      _ ->
        []
    end
  end

  defp build_slot_props(component, buffer, state, context_var) do
    component_slots =
      if component.type in [Surface.Component, Surface.LiveComponent] &&
           function_exported?(component.module, :__slots__, 0),
         do: component.module.__slots__(),
         else: []

    slot_info =
      component.slot_entries
      |> Enum.map(fn {name, slot_entries} ->
        state = %{state | scope: [:slot_entry | state.scope]}

        nested_slot_entries = handle_slot_entries(component, slot_entries, buffer, state)

        slot_name =
          Enum.find_value(component_slots, name, fn slot ->
            if slot.name == name do
              slot.opts[:as] || slot.name
            end
          end)

        {slot_name, nested_slot_entries}
      end)

    for {name, infos} <- slot_info, not Enum.empty?(infos) do
      entries =
        Enum.map(infos, fn {let, props, body} ->
          block =
            quote generated: true do
              {
                unquote({:%{}, [generated: true], let}),
                unquote(context_var)
              } ->
                unquote(body)
            end

          ast =
            quote do
              Phoenix.LiveView.Helpers.inner_block(unquote(name), do: unquote(block))
            end

          props = [__slot__: name, inner_block: ast] ++ props

          {:%{}, [generated: true], props}
        end)

      {name, entries}
    end
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

  defp handle_slot_entries(_component, [], _, _), do: []

  defp handle_slot_entries(
         component,
         [
           %AST.SlotEntry{
             name: name,
             props: props,
             let: let,
             children: children
           }
           | tail
         ],
         buffer,
         state
       ) do
    nested_block_state = %{
      state
      | depth: state.depth + 1,
        context_vars: %{state.context_vars | count: state.context_vars.count + 1}
    }

    props = collect_component_props(nil, props)

    [
      {add_default_bindings(component, name, let), props,
       handle_nested_block(children, buffer, nested_block_state)}
      | handle_slot_entries(component, tail, buffer, state)
    ]
  end

  defp handle_slot_entries(component, [slotable | tail], buffer, state) do
    %AST.SlotableComponent{
      slot: name,
      module: module,
      let: let,
      props: props,
      slot_entries: %{default: default}
    } = slotable

    slot_entry =
      cond do
        !module.__renderless__?() ->
          [
            %AST.Component{
              module: module,
              type: slotable.type,
              props: props,
              dynamic_props: nil,
              directives: [],
              slot_entries: slotable.slot_entries,
              meta: slotable.meta,
              debug: slotable.debug
            }
          ]

        Enum.empty?(default) ->
          []

        true ->
          %AST.SlotEntry{children: children} = List.first(default)
          children
      end

    props = collect_component_props(module, props)
    default_props = Surface.default_props(module)

    nested_block_state = %{
      state
      | depth: state.depth + 1,
        context_vars: %{state.context_vars | count: state.context_vars.count + 1}
    }

    [
      {add_default_bindings(component, name, let), Keyword.merge(default_props, props),
       handle_nested_block(slot_entry, buffer, nested_block_state)}
      | handle_slot_entries(component, tail, buffer, state)
    ]
  end

  defp add_default_bindings(%AST.FunctionComponent{}, _name, let) do
    let
  end

  defp add_default_bindings(%{module: %Surface.AST.AttributeExpr{}}, _name, let) do
    let
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
         %AST.MacroComponent{
           children: children,
           meta:
             %AST.Meta{
               module: mod,
               line: line
             } = meta
         } = component
         | nodes
       ])
       when not is_nil(mod) do
    %{attributes: attributes, directives: directives, meta: %{node_alias: node_alias}} = component
    store_component_call(meta.caller.module, node_alias, mod, attributes, directives, line)
    [to_dynamic_nested_html(children) | to_dynamic_nested_html(nodes)]
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

  defp to_dynamic_nested_html([%AST.VoidTag{element: element, attributes: attributes} | nodes]) do
    [
      "<",
      element,
      to_html_attributes(attributes),
      ">",
      to_dynamic_nested_html(nodes)
    ]
  end

  defp to_dynamic_nested_html([%AST.Tag{element: element, attributes: attributes, children: children} | nodes]) do
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

  defp to_dynamic_nested_html([%type{module: mod, slot_entries: slot_entries_by_name} = component | nodes])
       when type in [AST.Component, AST.FunctionComponent, AST.SlotableComponent] do
    {requires, slot_entries_by_name} =
      Enum.reduce(slot_entries_by_name, {[], %{}}, fn {name, slot_entries}, {requires_acc, by_name} ->
        {requires, slot_entries} =
          Enum.reduce(slot_entries, {requires_acc, []}, fn
            %AST.SlotEntry{children: children} = slot_entry, {requires, slot_entries} ->
              {requires, [%{slot_entry | children: to_token_sequence(children)} | slot_entries]}

            %AST.SlotableComponent{} = slot_entry, {requires, slot_entries} ->
              [nested, translated] = to_dynamic_nested_html([slot_entry])
              {[nested | requires], [translated | slot_entries]}
          end)

        {requires, Map.put(by_name, name, Enum.reverse(slot_entries))}
      end)

    %{caller: caller, node_alias: node_alias, line: line} = component.meta
    %{props: props, directives: directives} = component

    if type != AST.FunctionComponent do
      store_component_call(caller.module, node_alias, mod, props, directives, line)
    end

    [requires, %{component | slot_entries: slot_entries_by_name} | to_dynamic_nested_html(nodes)]
  end

  defp to_dynamic_nested_html([
         %AST.Error{message: message, meta: %AST.Meta{module: module, node_alias: node_alias} = meta} = component
         | nodes
       ])
       when not is_nil(module) do
    %{attributes: attributes, directives: directives} = component
    store_component_call(meta.caller.module, node_alias, module, attributes, directives, meta.line)

    [
      ~S(<span style="color: red; border: 2px solid red; padding: 3px"> Error: ),
      escape_message(message),
      ~S(</span>) | to_dynamic_nested_html(nodes)
    ]
  end

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
         %AST.Attribute{name: name, type: type, value: %AST.Literal{value: value}}
         | attributes
       ])
       when type in @string_types and is_binary(value) do
    [[" ", to_string(name), "=", ~S("), value, ~S(")], to_html_attributes(attributes)]
  end

  defp to_html_attributes([
         %AST.Attribute{name: name, type: type, value: %AST.Literal{value: value}}
         | attributes
       ]) do
    runtime_value = Surface.TypeHandler.expr_to_value!(type, name, [value], [], nil, value, _ctx = %{})
    [Surface.TypeHandler.attr_to_html!(type, to_string(name), runtime_value), to_html_attributes(attributes)]
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

      value = evaluate_literal_attribute(to_string(attr.name), attr.type, expr_value, attr.meta)

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
        Phoenix.HTML.raw(
          Surface.TypeHandler.attr_to_html!(unquote(type), unquote(to_string(name)), unquote(expr_value))
        )
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

  defp maybe_print_expression(expr, print?, file, line) do
    if print? do
      IO.puts(">>> DEBUG(EXPRESSION): #{file}:#{line}")
      expr |> Macro.to_string() |> Code.format_string!(line_length: 120) |> IO.puts()
      IO.puts("<<<")
    end

    expr
  end

  defp evaluate_literal_attribute(name, type, value, meta) do
    case Surface.TypeHandler.attr_to_html(type, name, value) do
      {:ok, attr} -> attr
      {:error, message} -> IOHelper.compile_error(message, meta.file, meta.line)
    end
  end

  defp require_expr(module, line) do
    %AST.Expr{
      value:
        quote generated: true, line: line do
          require(unquote(module)).__info__(:module)
        end,
      meta: %AST.Meta{}
    }
  end

  defp is_child_component?(state) do
    state.depth > 0 and Enum.member?(state.scope, :slot_entry)
  end

  defp escape_message(message) do
    {:safe, message_iodata} = Phoenix.HTML.html_escape(message)
    IO.iodata_to_binary(message_iodata)
  end

  defp context_name(count, caller) do
    "context_#{count}"
    |> String.to_atom()
    |> Macro.var(caller.module)
  end

  defp store_component_call(module, node_alias, component, props, directives, line) do
    # No need to store dynamic modules
    if !match?(%Surface.AST.AttributeExpr{}, component) do
      call = %{node_alias: node_alias, component: component, props: props, directives: directives, line: line}
      Module.put_attribute(module, :__components_calls__, call)
    end
  end

  defp process_context(module, fun, props, caller, state) do
    caller_is_module_component? =
      Module.get_attribute(caller.module, :component_type) && caller.function == {:render, 1}

    gets_context? =
      (function_exported?(module, :__gets_context__?, 1) and module.__gets_context__?({fun, 1})) or
        (module == Context and AST.has_attribute?(props, :get))

    changes_context? =
      (function_exported?(module, :__changes_context__?, 1) and module.__changes_context__?({fun, 1}) and
         module.__slots__() != []) or
        (module == Context and AST.has_attribute?(props, :put))

    if gets_context? do
      Module.put_attribute(caller.module, :gets_context?, caller.function)
    end

    if changes_context? do
      Module.put_attribute(caller.module, :changes_context?, caller.function)
    end

    initial_context =
      if caller_is_module_component? do
        quote do: @__context__
      else
        quote do: %{}
      end

    context_expr =
      cond do
        function_exported?(module, :__slots__?, 0) and module.__slots__() == [] and not gets_context? ->
          quote do: %{}

        state.context_vars.changed != [] && gets_context? ->
          quote do: Enum.reduce([unquote_splicing(state.context_vars.changed ++ [initial_context])], &Map.merge/2)

        true ->
          initial_context
      end

    context_var = context_name(state.context_vars.count, caller)

    state =
      if changes_context? do
        %{state | context_vars: %{state.context_vars | changed: [context_var | state.context_vars.changed]}}
      else
        state
      end

    {context_expr, context_var, state}
  end

  defp build_props_expressions(module, %{props: props, dynamic_props: dynamic_props}) do
    props_expr = collect_component_props(module, props)
    dynamic_props_expr = handle_dynamic_props(dynamic_props)

    {props_expr, dynamic_props_expr}
  end
end
