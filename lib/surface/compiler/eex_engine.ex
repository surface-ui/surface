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

  @phx_events Surface.Directive.Events.phx_events() |> Enum.map(&String.to_atom/1)

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
    ast = state.engine.handle_body(buffer, root: true)

    quote do
      require Phoenix.LiveView.TagEngine
      unquote(ast)
    end
  end

  defp generate_buffer([{:text, chars} | tail], buffer, state) do
    buffer = state.engine.handle_text(buffer, nil, chars)
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

    {:for, [], generator_expr}
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

    {:if, [], [condition, [do: if_buffer, else: else_buffer]]}
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
           arg: arg_expr,
           generator_value: generator_value_ast,
           context_put: context_put_list,
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

    context_expr = build_render_slot_context_expr(context_put_list, state, meta)

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

    generator_value =
      if generator_value_ast do
        %AST.AttributeExpr{value: generator_value} = generator_value_ast
        generator_value
      end

    slot_content_expr =
      quote line: meta.line do
        Phoenix.Component.render_slot(
          unquote(slot_value),
          {
            unquote(if(arg_expr, do: arg_expr.value, else: nil)),
            unquote(generator_value),
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

    # :__ignore__ is a private field meant to be used only in tools like the catalogue
    # to simulate the absence of an assigned slot based on an expression.
    quote do
      if unquote(slot_value) && !unquote(slot_value)[:__ignore__] do
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

    ctx = Surface.AST.Meta.quoted_caller_context(meta)
    {static_props, props_expr, dynamic_props_expr} = build_props_expressions(component, ctx)
    {context_expr, context_var, state} = process_context(nil, nil, props, component, state)
    slot_props = build_slot_props(component, buffer, state, context_var)
    static_props_map = {:%{}, [], slot_props ++ static_props}

    quote do
      Phoenix.LiveView.TagEngine.component(
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
          unquote(static_props_map)
        ),
        {__MODULE__, __ENV__.function, __ENV__.file, unquote(meta.line)}
      )
    end
    |> tag_slots(component)
    |> maybe_print_expression(component)
  end

  # Local function component
  defp to_expression(%AST.FunctionComponent{type: :local} = component, buffer, state) do
    %AST.FunctionComponent{module: module, fun: fun, props: props, meta: meta} = component

    ctx = Surface.AST.Meta.quoted_caller_context(meta)
    {static_props, props_expr, dynamic_props_expr} = build_props_expressions(component, ctx)
    {context_expr, context_var, state} = process_context(module, fun, props, component, state)
    slot_props = build_slot_props(component, buffer, state, context_var)
    static_props_map = {:%{}, [], slot_props ++ static_props}

    quote do
      Phoenix.LiveView.TagEngine.component(
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
          unquote(static_props_map)
        ),
        {__MODULE__, __ENV__.function, __ENV__.file, unquote(meta.line)}
      )
    end
    |> tag_slots(component)
    |> maybe_print_expression(component)
  end

  # Remote function component
  defp to_expression(%AST.FunctionComponent{type: :remote} = component, buffer, state) do
    %AST.FunctionComponent{module: module, fun: fun, props: props, meta: meta} = component

    ctx = Surface.AST.Meta.quoted_caller_context(meta)
    {static_props, props_expr, dynamic_props_expr} = build_props_expressions(component, ctx)
    {context_expr, context_var, state} = process_context(module, fun, props, component, state)
    slot_props = build_slot_props(component, buffer, state, context_var)
    static_props_map = {:%{}, [], slot_props ++ static_props}

    # For now, we can only retrieve props and slots information from module components,
    # not function components, so if we're dealing with dynamic or recursive module components,
    # we pass the module, otherwise, we pass `nil`.
    module_for_build_assigns = if fun == :render, do: module

    quote do
      Phoenix.LiveView.TagEngine.component(
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
          unquote(static_props_map)
        ),
        {__MODULE__, __ENV__.function, __ENV__.file, unquote(meta.line)}
      )
    end
    |> tag_slots(component)
    |> maybe_print_expression(component)
  end

  # Module stateless component
  defp to_expression(%AST.Component{type: Surface.Component} = component, buffer, state) do
    %AST.Component{module: module, props: props, meta: meta} = component

    ctx = Surface.AST.Meta.quoted_caller_context(meta)
    {static_props, props_expr, dynamic_props_expr} = build_props_expressions(component, ctx)
    {context_expr, context_var, state} = process_context(module, :render, props, component, state)
    slot_props = build_slot_props(component, buffer, state, context_var)
    static_props_map = {:%{}, [], static_props ++ slot_props}

    quote do
      Phoenix.LiveView.TagEngine.component(
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
          unquote(static_props_map)
        ),
        {__MODULE__, __ENV__.function, __ENV__.file, unquote(meta.line)}
      )
    end
    |> tag_slots(component)
    |> maybe_print_expression(component)
  end

  # Slotable component
  defp to_expression(%AST.SlotableComponent{} = component, buffer, state) do
    %AST.SlotableComponent{module: module, props: props, meta: meta} = component

    ctx = Surface.AST.Meta.quoted_caller_context(meta)
    {static_props, props_expr, dynamic_props_expr} = build_props_expressions(component, ctx)
    {context_expr, context_var, state} = process_context(module, :render, props, component, state)
    slot_props = build_slot_props(component, buffer, state, context_var)
    static_props_map = {:%{}, [], slot_props ++ static_props}

    quote do
      Phoenix.LiveView.TagEngine.component(
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
          unquote(static_props_map)
        ),
        {__MODULE__, __ENV__.function, __ENV__.file, unquote(meta.line)}
      )
    end
    |> tag_slots(component)
    |> maybe_print_expression(component)
  end

  # Live component
  defp to_expression(%AST.Component{type: Surface.LiveComponent} = component, buffer, state) do
    %AST.Component{module: module, props: props, meta: meta} = component

    ctx = Surface.AST.Meta.quoted_caller_context(meta)
    {static_props, props_expr, dynamic_props_expr} = build_props_expressions(component, ctx)
    {context_expr, context_var, state} = process_context(module, :render, props, component, state)
    slot_props = build_slot_props(component, buffer, state, context_var)
    static_props_map = {:%{}, [], [{:module, module} | slot_props] ++ static_props}

    quote do
      Phoenix.LiveView.TagEngine.component(
        &Phoenix.Component.live_component/1,
        Map.merge(
          Surface.build_assigns(
            unquote(context_expr),
            unquote(props_expr),
            unquote(dynamic_props_expr),
            unquote(module),
            unquote(meta.node_alias),
            unquote(ctx)
          ),
          unquote(static_props_map)
        ),
        {__MODULE__, __ENV__.function, __ENV__.file, unquote(meta.line)}
      )
    end
    |> tag_slots(component)
    |> maybe_print_expression(component)
  end

  # Dynamic live component
  defp to_expression(%AST.Component{type: :dynamic_live} = component, buffer, state) do
    %AST.Component{
      module: %AST.AttributeExpr{value: module_expr},
      props: props,
      meta: meta
    } = component

    ctx = Surface.AST.Meta.quoted_caller_context(meta)
    {static_props, props_expr, dynamic_props_expr} = build_props_expressions(component, ctx)
    {context_expr, context_var, state} = process_context(nil, :render, props, component, state)
    slot_props = build_slot_props(component, buffer, state, context_var)
    static_props_map = {:%{}, [], [{:module, module_expr} | slot_props] ++ static_props}

    quote do
      Phoenix.LiveView.TagEngine.component(
        &Phoenix.Component.live_component/1,
        Map.merge(
          Surface.build_dynamic_assigns(
            unquote(context_expr),
            unquote(props_expr),
            unquote(dynamic_props_expr),
            unquote(module_expr),
            unquote(meta.node_alias),
            unquote(ctx)
          ),
          unquote(static_props_map)
        ),
        {__MODULE__, __ENV__.function, __ENV__.file, unquote(meta.line)}
      )
    end
    |> tag_slots(component)
    |> maybe_print_expression(component)
  end

  # LiveView
  defp to_expression(%AST.Component{type: Surface.LiveView} = component, _buffer, _state) do
    %AST.Component{module: module, props: props} = component

    props_expr =
      collect_component_props(props)
      |> Enum.reject(fn {_, value} -> is_nil(value) end)

    quote do
      live_render(@socket, unquote(module), unquote(props_expr))
    end
    |> maybe_print_expression(component)
  end

  defp handle_dynamic_props(nil), do: []

  defp handle_dynamic_props(%AST.DynamicAttribute{expr: %AST.AttributeExpr{value: expr}}) do
    expr
  end

  defp collect_component_props(attrs) do
    Enum.reduce(attrs, [], fn attr, props ->
      %AST.Attribute{root: root, value: expr} = attr

      prop_name =
        if root do
          :__root__
        else
          attr.name
        end

      [{prop_name, to_prop_expr(expr)} | props]
    end)
    |> Enum.reverse()
  end

  # Function component
  defp build_slot_props(%AST.FunctionComponent{fun: fun} = component, buffer, state, _ctx_var) when fun != nil do
    for {name, slot_entries} <- component.slot_entries,
        state = %{state | scope: [:slot_entry | state.scope]},
        nested_slot_entries = handle_slot_entries(component, slot_entries, buffer, state),
        nested_slot_entries != [] do
      slot_name = if name == :default, do: :inner_block, else: name

      entries =
        Enum.map(nested_slot_entries, fn {let_expr, _generator, props, body, slot_entry_line} ->
          block =
            case let_expr do
              nil ->
                body

              %AST.AttributeExpr{value: {binding, _, nil} = let} when is_atom(binding) ->
                quote line: slot_entry_line do
                  unquote(let) ->
                    unquote(body)
                end

              %AST.AttributeExpr{value: let} ->
                quote line: slot_entry_line do
                  unquote(let) ->
                    unquote(body)

                  arg ->
                    unquote(
                      quote line: let_expr.meta.line do
                        raise ArgumentError,
                              "cannot match slot argument against :let. Expected a value matching #{unquote(Macro.to_string(let))}, got: `#{inspect(arg)}`."
                      end
                    )
                end
            end

          inner_block =
            quote do
              Phoenix.LiveView.TagEngine.inner_block(unquote(slot_name), do: unquote(block))
            end

          props = [__slot__: slot_name, inner_block: inner_block] ++ props

          {:%{}, [], props}
        end)

      {slot_name, entries}
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
        Enum.map(infos, fn {let_expr, generator_expr, props, body, slot_entry_line} ->
          let = if(let_expr == nil, do: quote(do: _), else: let_expr.value)
          no_warnings_generator = no_warnings_generator!(component, generator_expr, let, slot_entry_line)

          generator_line =
            if generator_expr do
              generator_expr.meta.line
            else
              slot_entry_line
            end

          {no_warnings_let, _} = make_bindings_ast_generated(let)

          validate_let_ast =
            if let_expr do
              quote line: let_expr.meta.line do
                if !match?(unquote(no_warnings_let), argument) do
                  raise ArgumentError,
                        "cannot match slot argument against :let. Expected a value matching `#{unquote(Macro.to_string(no_warnings_let))}`, got: #{inspect(argument)}."
                end
              end
            end

          validate_generator_ast =
            if !match?({var, _, ctx} when is_atom(var) and is_atom(ctx), no_warnings_generator) do
              quote line: generator_line do
                if !match?(unquote(no_warnings_generator), generator_value) do
                  raise ArgumentError,
                        "cannot match generator value against generator binding. Expected a value matching `#{unquote(Macro.to_string(no_warnings_generator))}`, got: #{inspect(generator_value)}."
                end
              end
            end

          block =
            quote generated: true, line: slot_entry_line do
              {
                unquote(let),
                unquote(no_warnings_generator),
                unquote(context_var)
              } ->
                unquote(body)

              {
                argument,
                generator_value,
                unquote(context_var)
              } ->
                unquote(validate_let_ast)
                unquote(validate_generator_ast)
            end

          ast =
            quote do
              Phoenix.LiveView.TagEngine.inner_block(unquote(name), do: unquote(block))
            end

          props = [__slot__: name, inner_block: ast] ++ props

          {:%{}, [], props}
        end)

      {name, entries}
    end
  end

  defp handle_nested_block(block, buffer, state) when is_list(block) do
    buffer = state.engine.handle_begin(buffer)

    buffer =
      Enum.reduce(block, buffer, fn
        {:text, chars}, buffer ->
          state.engine.handle_text(buffer, nil, chars)

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
             meta: meta,
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

    props = collect_component_props(props)

    [
      {let, generator_binding(component, name), props, handle_nested_block(children, buffer, nested_block_state),
       meta.line}
      | handle_slot_entries(component, tail, buffer, state)
    ]
  end

  defp handle_slot_entries(component, [slotable | tail], buffer, state) do
    %AST.SlotableComponent{
      slot: name,
      module: module,
      let: let,
      props: props,
      meta: meta,
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

    props = collect_component_props(props)
    default_props = Surface.default_props(module)

    nested_block_state = %{
      state
      | depth: state.depth + 1,
        context_vars: %{state.context_vars | count: state.context_vars.count + 1}
    }

    [
      {let, generator_binding(component, name), Keyword.merge(default_props, props),
       handle_nested_block(slot_entry, buffer, nested_block_state), meta.line}
      | handle_slot_entries(component, tail, buffer, state)
    ]
  end

  defp generator_binding(%AST.FunctionComponent{}, _name) do
    nil
  end

  defp generator_binding(%{module: %Surface.AST.AttributeExpr{}}, _name) do
    nil
  end

  defp generator_binding(%{module: module, props: props}, name) do
    with generator when not is_nil(generator) <- Keyword.get(module.__get_slot__(name).opts, :generator_prop),
         prop when not is_nil(prop) <- module.__get_prop__(generator),
         %AST.AttributeExpr{} = expr <- find_attribute_value(props, generator, prop.opts[:root], nil) do
      expr
    end
  end

  defp find_attribute_value(attrs, name, root, default)
  defp find_attribute_value([], _, _, default), do: default
  defp find_attribute_value([%AST.Attribute{root: true, value: value} | _], _, true, _), do: value

  defp find_attribute_value([%AST.Attribute{name: attr_name, value: value} | _], name, _root, _)
       when attr_name == name,
       do: value

  defp find_attribute_value([_ | tail], name, root, default),
    do: find_attribute_value(tail, name, root, default)

  defp to_prop_expr(%AST.AttributeExpr{} = expr) do
    case expr.value do
      {:__context_get__, scope, values} ->
        {scope, Enum.map(values, fn {key, {name, _, _}} -> {key, name} end)}

      {:__generator__, _, value} ->
        value

      value ->
        value
    end
  end

  defp to_prop_expr(%AST.Literal{value: value}) do
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
    store_component_call(meta.caller.module, node_alias, mod, attributes, directives, line, :compile)
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
      dep_type = if is_atom(mod) and function_exported?(mod, :transform, 1), do: :compile, else: :export
      store_component_call(caller.module, node_alias, mod, props, directives, line, dep_type)
    end

    [requires, %{component | slot_entries: slot_entries_by_name} | to_dynamic_nested_html(nodes)]
  end

  defp to_dynamic_nested_html([
         %AST.Error{message: message, meta: %AST.Meta{module: module, node_alias: node_alias} = meta} = component
         | nodes
       ])
       when not is_nil(module) do
    %{attributes: attributes, directives: directives} = component
    store_component_call(meta.caller.module, node_alias, module, attributes, directives, meta.line, :compile)

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
         %AST.Attribute{name: name, value: %AST.Literal{value: value}}
         | attributes
       ])
       when name in @phx_events and is_binary(value) do
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
      quote do
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
      quote do
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

  defp escape_message(message) do
    {:safe, message_iodata} = Phoenix.HTML.html_escape(message)
    IO.iodata_to_binary(message_iodata)
  end

  defp context_name(count, caller) do
    "context_#{count}"
    |> String.to_atom()
    |> Macro.var(caller.module)
  end

  defp store_component_call(module, node_alias, component, props, directives, line, dep_type)
       when dep_type in [:compile, :export] do
    # No need to store dynamic modules
    if !match?(%Surface.AST.AttributeExpr{}, component) do
      call = %{
        node_alias: node_alias,
        component: component,
        props: map_attrs(props),
        directives: map_attrs(directives),
        line: line,
        dep_type: dep_type
      }

      Module.put_attribute(module, :__components_calls__, call)
    end
  end

  defp map_attrs(attrs) do
    Enum.map(attrs, fn
      %AST.Attribute{} = attr ->
        %{name: attr.name, root: attr.root, line: attr.meta.line}

      %AST.Directive{} = attr ->
        %{name: attr.name, line: attr.meta.line}
    end)
  end

  defp process_context(module, fun, props, component, state) do
    caller = component.meta.caller

    caller_is_module_component? =
      Module.get_attribute(caller.module, :component_type) && caller.function == {:render, 1}

    # NOTE: Using this is not optimized as it will always assume the component propagates
    # context into into its slots.
    #
    # TODO: Force using directive :propagate_context_to_slots in dynamic components and remove the
    # `dynamic_component?` condition.
    dynamic_component? = module == nil and fun == nil

    if module == Context and AST.has_attribute?(props, :get) and state.context_vars.changed == [] do
      message = """
      using <Context get=.../> to retrieve values generated outside the template \
      has been deprecated. Use `from_context` instead and access the related assigns directly in the template.

      # Examples

          # as default value for an existing prop
          prop form, :form, from_context: {Form, :form}
          prop other, :any, from_context: :other

          # as internal state
          data form, :form, from_context: {Form, :form}
          data other, :any, from_context: :other
      """

      IOHelper.warn(message, component.meta.caller, component.meta.file, component.meta.line)
    end

    changes_context? =
      propagate_context_to_slots?(caller, module, fun) or
        (module == Context and AST.has_attribute?(props, :put)) or
        dynamic_component?

    initial_context =
      if caller_is_module_component? do
        quote do: @__context__
      else
        quote do: %{}
      end

    context_expr =
      if state.context_vars.changed != [] do
        changed_context_vars = Enum.map(state.context_vars.changed, fn {var, _component} -> var end)
        quote do: Enum.reduce([unquote_splicing(changed_context_vars ++ [initial_context])], &Map.merge/2)
      else
        initial_context
      end

    context_var = context_name(state.context_vars.count, caller)

    state =
      if changes_context? do
        %{
          state
          | context_vars: %{state.context_vars | changed: [{context_var, component} | state.context_vars.changed]}
        }
      else
        state
      end

    {context_expr, context_var, state}
  end

  defp build_render_slot_context_expr(context_put_list, state, meta) do
    caller = meta.caller
    module = caller.module
    fun = elem(caller.function, 0)

    if propagate_context_to_slots?(caller, module, fun) do
      # Top context
      context_expr = [quote(do: @__context__)]

      # Context variables from parent components
      context_expr =
        if state.context_vars.changed != [] do
          changed_context_vars = Enum.map(state.context_vars.changed, fn {var, _component} -> var end)
          quote(do: [unquote_splicing(changed_context_vars)]) ++ context_expr
        else
          context_expr
        end

      # Context values from `context_put`
      context_expr =
        if context_put_list != [] do
          context_kw =
            for %AST.AttributeExpr{value: {scope, items}} <- context_put_list, {key, value} <- items do
              {Context.normalize_key(scope, key), value}
            end

          [{:%{}, [], context_kw} | context_expr]
        else
          context_expr
        end

      case context_expr do
        [top_context] ->
          top_context

        _ ->
          quote do
            Enum.reduce(unquote(context_expr), &Map.merge/2)
          end
      end
    else
      if state.context_vars.changed != [] or context_put_list != [] do
        parents = state.context_vars.changed |> Enum.reverse() |> Enum.map(&elem(&1, 1))

        parents_text =
          if parents != [] do
            """

            Current parent components propagating context values:

                * #{Enum.map_join(parents, "\n    * ", fn c -> "`#{inspect(c.module)}` at line #{c.meta.line}" end)}
            """
          else
            ""
          end

        config_key = if fun == :render, do: inspect(module), else: "#{inspect(module)}, #{inspect(fun)}"

        message = """
        components propagating context values through slots must be configured \
        as `propagate_context_to_slots: true`.

        In case you don't want to propagate any value, you need to explicitly \
        set `propagate_context_to_slots` to `false`.

        # Example

        config :surface, :components, [
          {#{config_key}, propagate_context_to_slots: true},
          ...
        ]

        This warning is emitted whenever a <#slot ...> uses the `context_put` prop or \
        it's placed inside a parent component that propagates context values through its slots.
        #{parents_text}\
        """

        if emit_propagate_context_to_slots_warning?(caller, module, fun) do
          IOHelper.compile_error(message, meta.file, meta.line)
        end
      end

      quote(do: %{})
    end
  end

  defp build_props_expressions(%{module: module, props: attrs, dynamic_props: dynamic_props, meta: meta}, ctx) do
    module_expr =
      case module do
        %AST.AttributeExpr{value: module_expr} -> module_expr
        _ -> module
      end

    dynamic_props_expr = handle_dynamic_props(dynamic_props)

    {props_expr, props_with_dynamic_value} =
      Enum.reduce(attrs, {[], MapSet.new()}, fn attr, {props, props_with_dynamic_value} ->
        %AST.Attribute{root: root, value: expr} = attr
        value = to_prop_expr(expr)
        prop_name = if root, do: :__root__, else: attr.name

        # We consider a prop as dynamic if it has at least one dynamic value
        # TODO: use `Macro.quoted_literal?/1` instead
        props_with_dynamic_value =
          if is_binary(value) do
            props_with_dynamic_value
          else
            MapSet.put(props_with_dynamic_value, prop_name)
          end

        {[{prop_name, value} | props], props_with_dynamic_value}
      end)

    # We can't have this in the reduce above as we need the final `props_with_dynamic_value`
    {props_expr, static_props} =
      Enum.reduce(props_expr, {[], %{}}, fn {k, v}, {dynamic, static} ->
        if MapSet.member?(props_with_dynamic_value, k) do
          {[{k, v} | dynamic], static}
        else
          {dynamic, Map.put(static, k, [v | static[k] || []])}
        end
      end)

    static_props =
      for {k, v} <- static_props do
        ast =
          quote do
            Surface.TypeHandler.runtime_prop_value!(
              unquote(module_expr),
              unquote(k),
              unquote(v),
              [],
              unquote(meta.node_alias),
              nil,
              unquote(ctx)
            )
          end

        {k, ast}
      end

    {static_props, props_expr, dynamic_props_expr}
  end

  defp make_bindings_ast_generated(ast) do
    Macro.prewalk(ast, [], fn
      {var, _meta, nil} = node, acc when is_atom(var) ->
        generated_node = Macro.update_meta(node, fn meta -> Keyword.put(meta, :generated, true) end)
        {generated_node, [var | acc]}

      node, acc ->
        {node, acc}
    end)
  end

  defp extract_bindings_from_ast(ast) do
    {_, bindings} =
      Macro.prewalk(ast, [], fn
        {var, _meta, nil} = node, acc when is_atom(var) ->
          {node, [var | acc]}

        node, acc ->
          {node, acc}
      end)

    bindings
  end

  defp no_warnings_generator!(_component, nil, _let, _slot_entry_line), do: nil

  defp no_warnings_generator!(
         component,
         %AST.AttributeExpr{value: {:__generator__, generator, _value}} = generator_expr,
         let,
         slot_entry_line
       ) do
    {no_warnings_generator, generator_bindings} = make_bindings_ast_generated(generator)
    let_bindings = extract_bindings_from_ast(let)

    duplicated_bindings = MapSet.intersection(MapSet.new(generator_bindings), MapSet.new(let_bindings))

    if MapSet.size(duplicated_bindings) > 0 do
      message = """
      cannot use :let to redefine variable from the component's generator.

      #{Surface.Compiler.Helpers.list_to_string("variable", "variables", duplicated_bindings, &"`#{&1}`")} \
      already defined in `#{generator_expr.original}` \
      at #{Path.relative_to_cwd(generator_expr.meta.file)}:#{generator_expr.meta.line}

      Hint: choose a different name.\
      """

      IOHelper.compile_error(message, component.meta.file, slot_entry_line)
    end

    no_warnings_generator
  end

  defp propagate_context_to_slots?(caller, module, fun) do
    propagate_context_to_slots_map = get_propagate_context_to_slots_map(caller)
    Map.get(propagate_context_to_slots_map, {module, fun}, false)
  end

  defp emit_propagate_context_to_slots_warning?(caller, module, fun) do
    propagate_context_to_slots_map = get_propagate_context_to_slots_map(caller)
    not Map.has_key?(propagate_context_to_slots_map, {module, fun})
  end

  defp get_propagate_context_to_slots_map(caller) do
    Module.get_attribute(caller.module, :propagate_context_to_slots_map) ||
      Surface.BaseComponent.build_propagate_context_to_slots_map()
  end

  defp tag_slots({call, meta, args}, %AST.FunctionComponent{slot_entries: slot_entries}) do
    slots =
      Enum.map(slot_entries, fn
        {:default, _} -> :inner_block
        {name, _} -> name
      end)

    {call, [slots: slots] ++ meta, args}
  end

  defp tag_slots({call, meta, args}, %{slot_entries: slot_entries}) do
    slots = Enum.map(slot_entries, fn {name, _} -> name end)

    {call, [slots: slots] ++ meta, args}
  end
end
