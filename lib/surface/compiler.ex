defmodule Surface.Compiler do
  @moduledoc """
  Defines a behaviour that must be implemented by all HTML/Surface node translators.

  This module also contains the main logic to translate Surface code.
  """

  alias Surface.Compiler.Parser
  alias Surface.IOHelper
  alias Surface.AST
  alias Surface.Compiler.Helpers
  alias Surface.Compiler.CSSTranslator

  @tag_directive_handlers [
    Surface.Directive.TagAttrs,
    Surface.Directive.Events,
    Surface.Directive.Show,
    Surface.Directive.Hook,
    Surface.Directive.Values,
    Surface.Directive.If,
    Surface.Directive.For,
    Surface.Directive.Debug
  ]

  @component_directive_handlers [
    Surface.Directive.Let,
    Surface.Directive.ComponentProps,
    Surface.Directive.If,
    Surface.Directive.For,
    Surface.Directive.Debug
  ]

  @meta_component_directive_handlers [
    Surface.Directive.If,
    Surface.Directive.For,
    Surface.Directive.Debug
  ]

  @slot_entry_directive_handlers [Surface.Directive.Let]

  @slot_directive_handlers [
    Surface.Directive.If,
    Surface.Directive.For
  ]

  @valid_slot_props [:root, "generator_value", "context_put"]

  @directive_prefixes [":", "s-"]

  @void_elements [
    "area",
    "base",
    "br",
    "col",
    "command",
    "embed",
    "hr",
    "img",
    "input",
    "keygen",
    "link",
    "meta",
    "param",
    "source",
    "track",
    "wbr"
  ]

  # TODO: Add all relevant information from the caller (when it's a component), e.g. props, data, style, etc.
  # Make the compiler use this struct instead of calls to Surface.API.*(caller.module)
  defmodule CallerSpec do
    defstruct type: nil,
              props: [],
              variants: [],
              data_variants: [],
              requires_s_self_on_root?: false,
              requires_s_scope_on_root?: false,
              has_style_or_variants?: false,
              scope_id: nil

    @type t :: %__MODULE__{
            type: module(),
            props: list(),
            variants: list(),
            data_variants: list(),
            requires_s_self_on_root?: boolean(),
            requires_s_scope_on_root?: boolean(),
            has_style_or_variants?: boolean(),
            scope_id: binary()
          }
  end

  defmodule CompileMeta do
    defstruct [:line, :file, :caller, :checks, :variables, :module, :style, :caller_spec]

    @type t :: %__MODULE__{
            line: non_neg_integer(),
            file: binary(),
            caller: Macro.Env.t(),
            variables: keyword(),
            checks: Keyword.t(boolean()),
            caller_spec: CallerSpec.t(),
            style: map()
          }
  end

  @doc """
  This function compiles a string into the Surface AST.This is used by ~F and Surface.Renderer to parse and compile templates.

  A special note for line: This is considered the line number for the first line in the string. If the first line of the
  string is also the first line of the file, then this should be 1. If this is being called within a macro (say to process a heredoc
  passed to ~F), this should be __CALLER__.line + 1.
  """
  @spec compile(binary, non_neg_integer(), Macro.Env.t(), binary(), Keyword.t()) :: [
          Surface.AST.t()
        ]
  def compile(string, line, caller, file \\ "nofile", opts \\ []) do
    tokens =
      Parser.parse!(string,
        file: file,
        line: line,
        caller: caller,
        checks: opts[:checks] || [],
        warnings: opts[:warnings] || [],
        column: Keyword.get(opts, :column, 1),
        indentation: Keyword.get(opts, :indentation, 0)
      )

    {style, tokens} =
      tokens
      |> skip_blanks()
      |> maybe_pop_style(caller, [file: file, line: line] ++ opts)

    caller_spec = build_caller_spec(caller, style)

    compile_meta = %CompileMeta{
      line: line,
      file: file,
      caller: caller,
      checks: opts[:checks] || [],
      variables: opts[:variables],
      style: style,
      caller_spec: caller_spec
    }

    tokens
    |> skip_blanks()
    |> to_ast(compile_meta)
    |> maybe_transform_ast(compile_meta)
    |> validate_component_structure(compile_meta, caller.module)
  end

  defp build_caller_spec(caller, style) do
    component_type =
      if Module.open?(caller.module) do
        Module.get_attribute(caller.module, :component_type)
      end

    use_deep_at_the_beginning? = Map.get(style, :use_deep_at_the_beginning?, false)

    caller_spec = %CallerSpec{
      type: component_type,
      scope_id: style.scope_id,
      requires_s_self_on_root?: use_deep_at_the_beginning?,
      requires_s_scope_on_root?: use_deep_at_the_beginning?,
      has_style_or_variants?: Map.has_key?(style, :css)
    }

    if component_type do
      # Currently, we only support props and data for the module components
      {props, datas} =
        if caller.function == {:render, 1} do
          {Surface.API.get_props(caller.module), Surface.API.get_data(caller.module)}
        else
          {[], []}
        end

      {variants, data_variants} = Surface.Compiler.Variants.generate(props ++ datas)

      define_variants? = variants != []

      %CallerSpec{
        caller_spec
        | props: props,
          variants: variants,
          data_variants: data_variants,
          requires_s_self_on_root?: caller_spec.requires_s_self_on_root? or define_variants?,
          requires_s_scope_on_root?: caller_spec.requires_s_scope_on_root? or define_variants?,
          has_style_or_variants?: caller_spec.has_style_or_variants? or define_variants?
      }
    else
      caller_spec
    end
  end

  def to_live_struct(nodes, opts \\ []) do
    Surface.Compiler.EExEngine.translate(nodes, opts)
  end

  def validate_component_structure(ast, meta, module) do
    if Helpers.is_stateful_component(module) do
      validate_stateful_component(ast, meta)
    end

    ast
  end

  defp validate_stateful_component(ast, %CompileMeta{caller: %{function: {:render, _}}} = compile_meta) do
    num_tags =
      ast
      |> Enum.filter(fn
        %AST.Tag{} ->
          true

        %AST.VoidTag{} ->
          true

        %AST.Component{type: Surface.LiveComponent, meta: meta} ->
          warn_live_component_as_root_node_of_another_live_component(meta, compile_meta.caller)

          true

        %AST.Component{} ->
          true

        _ ->
          false
      end)
      |> Enum.count()

    cond do
      num_tags == 0 ->
        IOHelper.warn(
          "stateful live components must have a HTML root element",
          compile_meta.caller,
          compile_meta.file,
          compile_meta.line
        )

      num_tags > 1 ->
        IOHelper.warn(
          "stateful live components must have a single HTML root element",
          compile_meta.caller,
          compile_meta.file,
          compile_meta.line
        )

      true ->
        :noop
    end
  end

  defp validate_stateful_component(_ast, %CompileMeta{}), do: nil

  defp warn_live_component_as_root_node_of_another_live_component(meta, caller) do
    IOHelper.warn(
      """
      cannot have a LiveComponent as root node of another LiveComponent.

      Hint: You can wrap the root `#{meta.node_alias}` node in another element. Example:

        def render(assigns) do
          ~F"\""
          <div>
            <#{meta.node_alias} ... >
              ...
            </#{meta.node_alias}>
          </div>
          "\""
        end
      """,
      caller,
      meta.file,
      meta.line
    )
  end

  def to_ast(nodes, compile_meta) do
    for node <- List.wrap(nodes),
        result = convert_node_to_ast(node_type(node), node, compile_meta),
        result != :ignore do
      case result do
        {:ok, ast} ->
          process_directives(ast)

        {:error, {message, line, column}, meta} ->
          IOHelper.warn(message, compile_meta.caller, meta.file, {line, column})
          %AST.Error{message: message, meta: meta}

        {:error, {message, details, line, column}, meta} ->
          # TODO: turn it back as a warning when using @after_verify in Elixir >= 0.14.
          # Make sure to check if the genarated `require <component>.__info__()` doesn't get called,
          # raising Elixir's CompileError.
          IOHelper.compile_error(message, details, meta.file, {line, column})
          %AST.Error{message: message, meta: meta}
      end
    end
  end

  # Slots
  defp node_type({"#slot", _, _, _}), do: :slot
  defp node_type({":" <> _, _, _, _}), do: :slot_entry

  # Conditional blocks
  defp node_type({:block, "if", _, _, _}), do: :if_elseif_else
  defp node_type({:block, "elseif", _, _, _}), do: :if_elseif_else
  defp node_type({:block, "else", _, _, _}), do: :else
  defp node_type({:block, "unless", _, _, _}), do: :unless

  # For
  defp node_type({:block, "for", _, _, _}), do: :for_else

  # case/match
  defp node_type({:block, "case", _, _, _}), do: :block
  defp node_type({:block, "match", _, _, _}), do: :sub_block
  defp node_type({:block, :default, _, _, _}), do: :sub_block

  defp node_type({:ast, _, _}), do: :ast

  # Components
  defp node_type({"#" <> _, _, _, _}), do: :macro_component
  defp node_type({_, _, _, %{decomposed_tag: {:component, _, _}}}), do: :component
  defp node_type({_, _, _, %{decomposed_tag: {:recursive_component, _, _}}}), do: :recursive_component
  defp node_type({_, _, _, %{decomposed_tag: {:remote, _, _}}}), do: :function_component
  defp node_type({_, _, _, %{decomposed_tag: {:local, _, _}}}), do: :function_component

  # HTML elements
  defp node_type({name, _, _, _}) when name in @void_elements, do: :void_tag
  defp node_type({_, _, _, _}), do: :tag

  # Other
  defp node_type({:expr, _, _}), do: :interpolation
  defp node_type({:comment, _, _}), do: :comment
  defp node_type(_), do: :text

  defp process_directives(%{directives: directives} = node) when is_list(directives) do
    node_is_tag? = match?(%AST.Tag{}, node)

    {directives, _} =
      for %AST.Directive{module: mod, meta: meta} = directive <- directives,
          function_exported?(mod, :process, 2),
          reduce: {node, MapSet.new()} do
        {node, processed_directives} ->
          if node_is_tag? and MapSet.member?(processed_directives, directive.name) do
            message = """
            the directive `:#{format_directive_name(directive.name)}` has been passed multiple times. Considering only the last value.

            Hint: remove all redundant definitions.
            """

            IOHelper.warn(message, meta.caller, meta.file, meta.line)
          end

          {mod.process(directive, node), MapSet.put(processed_directives, directive.name)}
      end

    directives
  end

  defp process_directives(node), do: node

  defp format_directive_name(directive_name) do
    if to_string(directive_name) in Surface.Directive.Events.names(),
      do: "on-#{directive_name}",
      else: directive_name
  end

  defp convert_node_to_ast(:comment, {_, _comment, %{visibility: :private}}, _), do: :ignore

  defp convert_node_to_ast(:comment, {_, comment, %{visibility: :public}}, _),
    do: {:ok, %AST.Literal{value: comment}}

  defp convert_node_to_ast(:text, text, _),
    do: {:ok, %AST.Literal{value: text}}

  defp convert_node_to_ast(:interpolation, {_, text, node_meta}, compile_meta) do
    meta = Helpers.to_meta(node_meta, compile_meta)

    expr = Helpers.expression_to_quoted!(text, meta)

    Helpers.perform_assigns_checks(expr, compile_meta)

    {:ok,
     %AST.Interpolation{
       original: text,
       value: expr,
       meta: meta,
       constant?: Macro.quoted_literal?(expr)
     }}
  end

  defp convert_node_to_ast(:ast, {_, variable, expr_meta}, compile_meta) do
    meta = Helpers.to_meta(expr_meta, compile_meta)
    ast = unquote_variable!(variable, compile_meta, meta)
    {:ok, ast}
  end

  defp convert_node_to_ast(:else, {:block, _name, _expr, children, node_meta}, compile_meta) do
    meta = Helpers.to_meta(node_meta, compile_meta)
    {:ok, %AST.Container{children: to_ast(children, compile_meta), meta: meta, directives: []}}
  end

  defp convert_node_to_ast(:if_elseif_else, {:block, _name, attributes, children, node_meta}, compile_meta) do
    meta = Helpers.to_meta(node_meta, compile_meta)
    default = AST.AttributeExpr.new(false, "", node_meta)
    condition = attribute_value_as_ast(attributes, :root, default, compile_meta)

    [if_children, else_children] =
      case children do
        [{:block, :default, [], default, _}, {:block, "else", _, _, _} = else_block] ->
          [default, [else_block]]

        [{:block, :default, [], default, _}, {:block, "elseif", a, c, m} | rest] ->
          [default, [{:block, "elseif", a, [{:block, :default, [], c, %{}} | rest], m}]]

        [{:block, :default, [], default, _}] ->
          [default, []]

        children ->
          [children, []]
      end

    {:ok,
     %AST.If{
       condition: condition,
       children: to_ast(if_children, compile_meta),
       else: to_ast(else_children, compile_meta),
       meta: meta
     }}
  end

  defp convert_node_to_ast(:sub_block, {:block, :default, _attrs, [], _meta}, _compile_meta) do
    :ignore
  end

  defp convert_node_to_ast(:sub_block, {:block, name, attrs, children, meta}, compile_meta) do
    {:ok,
     %AST.SubBlock{
       name: name,
       expression: quoted_block_expression(attrs),
       children: to_ast(children, compile_meta),
       meta: Helpers.to_meta(meta, compile_meta)
     }}
  end

  defp convert_node_to_ast(:block, {:block, "case", _, _, %{has_sub_blocks?: false} = node_meta}, compile_meta) do
    meta = Helpers.to_meta(node_meta, compile_meta)

    message = "no {#match} sub-block defined. A {#case} block must include at least one {#match ...} sub-block."

    IOHelper.compile_error(message, meta.file, meta.line)
  end

  defp convert_node_to_ast(:block, {:block, name, attrs, children, meta}, compile_meta) do
    {:ok,
     %AST.Block{
       name: name,
       expression: quoted_block_expression(attrs),
       sub_blocks: to_ast(children, compile_meta),
       meta: Helpers.to_meta(meta, compile_meta)
     }}
  end

  defp convert_node_to_ast(:unless, {:block, _name, attributes, children, node_meta}, compile_meta) do
    meta = Helpers.to_meta(node_meta, compile_meta)
    default = AST.AttributeExpr.new(false, "", meta)
    condition = attribute_value_as_ast(attributes, :root, default, compile_meta)

    {:ok,
     %AST.If{
       condition: condition,
       children: [],
       else: to_ast(children, compile_meta),
       meta: meta
     }}
  end

  defp convert_node_to_ast(:for_else, {:block, _name, attributes, children, node_meta}, compile_meta) do
    meta = Helpers.to_meta(node_meta, compile_meta)
    default = AST.AttributeExpr.new(false, "", meta)
    generator = attribute_value_as_ast(attributes, :root, :generator, default, compile_meta)

    [for_children, else_children] =
      case children do
        [{:block, :default, [], default, _}, {:block, "else", _, _, _} = else_block] ->
          [default, [else_block]]

        children ->
          [children, []]
      end

    for_ast = %AST.For{
      generator: generator,
      children: to_ast(for_children, compile_meta),
      else: to_ast(else_children, compile_meta),
      meta: meta
    }

    if else_children == [] do
      {:ok, for_ast}
    else
      [else_ast | _] = to_ast(else_children, compile_meta)

      value =
        case generator.value do
          [{:<-, _, [_, value]}] -> value
          _ -> raise_complex_generator(else_ast.meta)
        end

      condition_expr =
        quote do
          unquote(value) != []
        end

      condition = AST.AttributeExpr.new(condition_expr, "", meta)

      {:ok,
       %AST.If{
         condition: condition,
         children: [for_ast],
         else: [else_ast],
         meta: meta
       }}
    end
  end

  defp convert_node_to_ast(:slot_entry, {name, attributes, children, node_meta}, compile_meta) do
    meta = Helpers.to_meta(node_meta, compile_meta)

    with {:ok, directives, attributes} <-
           collect_directives(@slot_entry_directive_handlers, attributes, meta),
         slot <- get_slot_name(name, attributes),
         attributes <- process_attributes(nil, attributes, meta, compile_meta) do
      {:ok,
       %AST.SlotEntry{
         name: slot,
         children: to_ast(children, compile_meta),
         props: attributes,
         directives: directives,
         let: nil,
         meta: meta
       }}
    else
      _ -> {:error, {"failed to parse slot entry", meta.line}, meta}
    end
  end

  defp convert_node_to_ast(:slot, {_, attributes, children, node_meta}, compile_meta) do
    meta = Helpers.to_meta(node_meta, compile_meta)

    defined_slots =
      if Module.get_attribute(meta.caller.module, :component_type) do
        meta.caller.module
        |> Surface.API.get_slots()
      else
        [
          %{
            doc: "The default slot",
            func: :slot,
            line: node_meta.line,
            name: :default,
            opts: [],
            opts_ast: [],
            type: :any
          }
        ]
      end

    has_root? = has_attribute?(attributes, :root)
    name = extract_name_from_root(attributes)

    name =
      if !name and !has_root? do
        :default
      else
        name
      end

    default_syntax? = not has_root?

    render_slot_args =
      if has_root? do
        attribute_value_as_ast(attributes, :root, :render_slot, %Surface.AST.Literal{value: nil}, compile_meta)
      end

    slot_entry_ast =
      if has_root? do
        render_slot_args.slot
      end

    {:ok, directives, attrs} = collect_directives(@slot_directive_handlers, attributes, meta)
    validate_slot_attrs!(attrs, meta.caller)

    slot =
      Enum.find(defined_slots, fn slot ->
        slot.name == name || (Keyword.has_key?(slot.opts, :as) and slot.opts[:as] == name)
      end)

    arg =
      if has_root? do
        render_slot_args.argument
      else
        nil
      end

    if slot do
      maybe_warn_required_slot_with_default_value(
        slot,
        children,
        slot_entry_ast,
        meta
      )

      maybe_warn_argument_for_default_slot_in_slotable_component(slot, arg, meta)
    end

    if name && !slot do
      raise_missing_slot_error!(
        meta.caller.module,
        name,
        meta,
        defined_slots,
        default_syntax?
      )
    end

    generator_value =
      cond do
        has_attribute?(attributes, "generator_value") ->
          attribute_value_as_ast(
            attributes,
            "generator_value",
            :any,
            %Surface.AST.Literal{value: nil},
            compile_meta
          )

        slot && Keyword.has_key?(slot.opts, :generator_prop) ->
          IOHelper.compile_error("`generator_value` is missing for slot `#{slot.name}`", meta.file, meta.line)

        true ->
          nil
      end

    context_put =
      for {"context_put", {:attribute_expr, value, expr_meta}, _attr_meta} <- attributes do
        expr_meta = Helpers.to_meta(expr_meta, meta)
        expr = Surface.TypeHandler.expr_to_quoted!(value, "context_put", :context_put, expr_meta)
        AST.AttributeExpr.new(expr, value, expr_meta)
      end

    {:ok,
     %AST.Slot{
       name: name,
       as: if(slot, do: slot[:opts][:as]),
       for: slot_entry_ast,
       directives: directives,
       default: to_ast(children, compile_meta),
       arg: arg,
       generator_value: generator_value,
       context_put: context_put,
       meta: meta
     }}
  end

  defp convert_node_to_ast(:tag, {name, attributes, children, node_meta}, compile_meta) do
    meta = Helpers.to_meta(node_meta, compile_meta)

    with {:ok, directives, attributes} <-
           collect_directives(@tag_directive_handlers, attributes, meta),
         attributes <- process_attributes(nil, attributes, meta, compile_meta),
         children <- to_ast(children, compile_meta),
         :ok <- validate_tag_children(children) do
      {:ok,
       maybe_transform_tag(
         %AST.Tag{
           element: name,
           attributes: attributes,
           directives: directives,
           children: children,
           meta: meta
         },
         compile_meta
       )}
    else
      {:error, message, meta} -> handle_convert_node_to_ast_error(name, {:error, message}, meta)
      error -> handle_convert_node_to_ast_error(name, error, meta)
    end
  end

  defp convert_node_to_ast(:void_tag, {name, attributes, children, node_meta}, compile_meta) do
    meta = Helpers.to_meta(node_meta, compile_meta)

    with {:ok, directives, attributes} <-
           collect_directives(@tag_directive_handlers, attributes, meta),
         attributes <- process_attributes(nil, attributes, meta, compile_meta),
         # a void element containing content is an error
         [] <- to_ast(children, compile_meta) do
      {:ok,
       maybe_transform_tag(
         %AST.VoidTag{
           element: name,
           attributes: attributes,
           directives: directives,
           meta: meta
         },
         compile_meta
       )}
    else
      error -> handle_convert_node_to_ast_error(name, error, meta)
    end
  end

  defp convert_node_to_ast(:function_component, node, compile_meta) do
    {name, attributes, children, %{decomposed_tag: {type, mod, fun}} = node_meta} = node

    meta =
      node_meta
      |> Helpers.to_meta(compile_meta)
      |> Map.merge(%{module: mod, node_alias: name})

    with {:ok, slot_entries, attributes} <- collect_slot_entries(mod, attributes, children, meta),
         {:ok, directives, attributes} <- collect_directives(@component_directive_handlers, attributes, meta),
         attributes <- process_attributes(nil, attributes, meta, compile_meta) do
      ast = %AST.FunctionComponent{
        module: mod,
        fun: fun,
        type: type,
        props: attributes,
        directives: directives,
        slot_entries: slot_entries,
        meta: meta
      }

      {:ok, maybe_transform_component_ast(ast, compile_meta)}
    else
      error -> handle_convert_node_to_ast_error(name, error, meta)
    end
  end

  # Recursive components must be represented as function components
  # until we can validate slot entries and properties of open modules
  defp convert_node_to_ast(:recursive_component, node, compile_meta) do
    {name, attributes, children, %{decomposed_tag: {_, mod, _}} = node_meta} = node

    meta =
      node_meta
      |> Helpers.to_meta(compile_meta)
      |> Map.merge(%{module: mod, node_alias: name})

    # TODO: we should call validate_slot_entries/3 validate
    # based on the module attributes since the module is still open
    with component_type <- Module.get_attribute(mod, :component_type),
         true <- component_type != nil,
         # This is a little bit hacky. :let will only be extracted for the default
         # slot entry if `mod` doesn't export __slot_name__ (i.e. if it isn't a slotable component)
         # we pass in and modify the attributes so that non-slotable components are not
         # processed by the :let directive
         {:ok, slot_entries, attributes} <- collect_slot_entries(mod, attributes, children, meta),
         {:ok, directives, attributes} <- collect_directives(@component_directive_handlers, attributes, meta),
         attributes <- process_attributes(nil, attributes, meta, compile_meta) do
      ast = %AST.FunctionComponent{
        module: mod,
        fun: :render,
        type: :remote,
        props: attributes,
        directives: directives,
        slot_entries: slot_entries,
        meta: meta
      }

      {:ok, maybe_transform_component_ast(ast, compile_meta)}
    else
      error -> handle_convert_node_to_ast_error(name, error, meta)
    end
  end

  defp convert_node_to_ast(:component, {name, attributes, children, node_meta}, compile_meta) do
    {_type, mod, _fun} = node_meta.decomposed_tag

    meta =
      node_meta
      |> Helpers.to_meta(compile_meta)
      |> Map.merge(%{module: mod, node_alias: name})

    with :ok <- Helpers.validate_component_module(mod, name),
         true <- function_exported?(mod, :component_type, 0),
         component_type <- mod.component_type(),
         # This is a little bit hacky. :let will only be extracted for the default
         # slot entry if `mod` doesn't export __slot_name__ (i.e. if it isn't a slotable component)
         # we pass in and modify the attributes so that non-slotable components are not
         # processed by the :let directive
         {:ok, slot_entries, attributes} <- collect_slot_entries(mod, attributes, children, meta),
         :ok <- validate_slot_entries(mod, slot_entries, meta),
         {:ok, directives, attributes} <- collect_directives(@component_directive_handlers, attributes, meta),
         attributes <- process_attributes(mod, attributes, meta, compile_meta) do
      result =
        if component_slotable?(mod) do
          %AST.SlotableComponent{
            module: mod,
            slot: mod.__slot_name__(),
            type: component_type,
            let: nil,
            props: attributes,
            directives: directives,
            slot_entries: slot_entries,
            meta: meta
          }
        else
          %AST.Component{
            module: mod,
            type: component_type,
            props: attributes,
            directives: directives,
            slot_entries: slot_entries,
            meta: meta
          }
        end

      {:ok, maybe_transform_component_ast(result, compile_meta)}
    else
      error -> handle_convert_node_to_ast_error(name, error, meta)
    end
  end

  defp convert_node_to_ast(
         :macro_component,
         {"#" <> name = node_alias, attributes, children, node_meta},
         compile_meta
       ) do
    meta = Helpers.to_meta(node_meta, compile_meta)
    mod = Helpers.actual_component_module!(name, meta.caller)
    meta = Map.merge(meta, %{module: mod, node_alias: node_alias})

    with :ok <- Helpers.validate_component_module(mod, name),
         meta <- Map.merge(meta, %{module: mod, node_alias: node_alias}),
         true <- function_exported?(mod, :expand, 3),
         {:ok, directives, attributes} <-
           collect_directives(@meta_component_directive_handlers, attributes, meta),
         attributes <- process_attributes(mod, attributes, meta, compile_meta) do
      case validate_properties(mod, attributes) do
        :ok ->
          expanded_children = mod.expand(attributes, List.to_string(children), meta)

          {:ok,
           %AST.MacroComponent{
             attributes: attributes,
             children: List.wrap(expanded_children),
             directives: directives,
             meta: meta
           }}

        :missing_required_props ->
          message = "cannot render <#{node_alias}> (missing required props)"
          {:ok, %AST.Error{attributes: attributes, message: message, meta: meta}}
      end
    else
      false ->
        {:error,
         {"cannot render <#{node_alias}> (MacroComponents must export an expand/3 function)", meta.line,
          meta.column}, meta}

      error ->
        handle_convert_node_to_ast_error(node_alias, error, meta)
    end
  end

  defp maybe_transform_component_ast(%AST.FunctionComponent{} = node, compile_meta) do
    maybe_add_caller_scope_id_prop(node, compile_meta)
  end

  defp maybe_transform_component_ast(node, compile_meta) do
    node
    |> maybe_call_transform()
    |> maybe_add_caller_scope_id_prop(compile_meta)
  end

  defp maybe_call_transform(%{module: module} = node) do
    if function_exported?(module, :transform, 1) do
      module.transform(node)
    else
      node
    end
  end

  defp maybe_add_caller_scope_id_prop(node, %mod{caller_spec: %{has_style_or_variants?: true} = caller_spec})
       when mod in [CompileMeta, AST.Meta] do
    %{meta: meta, props: props} = node
    %CallerSpec{scope_id: scope_id} = caller_spec

    prop = %AST.Attribute{
      meta: meta,
      name: :__caller_scope_id__,
      type: :string,
      value: %AST.Literal{value: scope_id}
    }

    %{node | props: [prop | props]}
  end

  defp maybe_add_caller_scope_id_prop(node, _compile_meta) do
    node
  end

  defp maybe_add_caller_scope_id_attr_to_root_node(%type{} = node, %CallerSpec{} = caller_spec)
       when type in [AST.Tag, AST.VoidTag] do
    is_caller_a_component? = caller_spec.type != nil

    # TODO: when support for `attr` is added, check for :css_class types instead
    function_component? = node.meta.caller.function != {:render, 1}

    has_css_class_prop? = fn ->
      Enum.any?(caller_spec.props, &(&1.type == :css_class))
    end

    passing_class_expr? = fn node ->
      class = AST.find_attribute_value(node.attributes, :class)
      match?(%AST.AttributeExpr{}, class)
    end

    attributes =
      if is_caller_a_component? and passing_class_expr?.(node) and (has_css_class_prop?.() or function_component?) do
        prefix = CSSTranslator.scope_attr_prefix()
        # Quoted expression for ["the-prefix-#{@__caller_scope_id__}": !!@__caller_scope_id__]
        expr =
          quote do
            [
              "#{unquote(prefix)}#{var!(assigns)[:__caller_scope_id__]}":
                {{:boolean, []}, !!var!(assigns)[:__caller_scope_id__]}
            ]
          end

        data_caller_scope_id_attr = %AST.DynamicAttribute{
          meta: node.meta,
          expr: AST.AttributeExpr.new(expr, "", node.meta)
        }

        [data_caller_scope_id_attr | node.attributes]
      else
        node.attributes
      end

    %{node | attributes: attributes}
  end

  defp maybe_add_caller_scope_id_attr_to_root_node(node, _caller_spec) do
    node
  end

  defp attribute_raw_value(attributes, attr_name, default) do
    Enum.find_value(attributes, default, fn
      {^attr_name, {:attribute_expr, expr, _}, _} ->
        expr

      _ ->
        nil
    end)
  end

  defp extract_name_from_root(attributes) do
    with value when is_binary(value) <- attribute_raw_value(attributes, :root, nil),
         {:ok, [{:@, _, [{assign_name, _, _}]} | _rest]} <-
           Code.string_to_quoted("[#{value}]") do
      assign_name
    else
      {:error, _} ->
        # TODO: raise
        nil

      _ ->
        nil
    end
  end

  defp has_attribute?([], _), do: false

  defp has_attribute?(attributes, attr_name),
    do: Enum.any?(attributes, &match?({^attr_name, _, _}, &1))

  defp attribute_value_as_ast(attributes, attr_name, type \\ :integer, default, meta) do
    Enum.find_value(attributes, default, fn
      {^attr_name, {:attribute_expr, value, expr_meta}, _attr_meta} ->
        expr_meta = Helpers.to_meta(expr_meta, meta)
        expr = Surface.TypeHandler.expr_to_quoted!(value, attr_name, type, expr_meta)

        if type == :render_slot do
          %{slot: slot, argument: argument} = expr

          %{
            slot: AST.AttributeExpr.new(slot, value, expr_meta),
            argument: AST.AttributeExpr.new(argument, value, expr_meta)
          }
        else
          AST.AttributeExpr.new(expr, value, expr_meta)
        end

      {^attr_name, value, attr_meta} ->
        attr_meta = Helpers.to_meta(attr_meta, meta)
        Surface.TypeHandler.literal_to_ast_node!(type, attr_name, value, attr_meta)

      _ ->
        nil
    end)
  end

  defp quoted_block_expression([{:root, {:attribute_expr, value, expr_meta}, _attr_meta}]) do
    Helpers.expression_to_quoted!(value, expr_meta)
  end

  defp quoted_block_expression([]) do
    nil
  end

  defp get_slot_name(":" <> name, _), do: String.to_atom(name)

  defp component_slotable?(mod), do: function_exported?(mod, :__slot_name__, 0)

  defp process_attributes(_module, [], _meta, _compile_meta), do: []

  defp process_attributes(mod, attrs, meta, compile_meta),
    do: process_attributes(mod, attrs, meta, compile_meta, [])

  defp process_attributes(_module, [], _meta, _compile_meta, acc) do
    acc
    |> Keyword.values()
    |> Enum.reverse()
  end

  defp process_attributes(mod, [{:root, value, attr_meta} | attrs], meta, compile_meta, acc) do
    attr_meta = Helpers.to_meta(attr_meta, meta)
    name = nil

    {ast_name, type} =
      with true <- function_exported?(mod, :__props__, 0),
           prop when not is_nil(prop) <- Enum.find(mod.__props__(), & &1.opts[:root]) do
        {prop.name, prop.type}
      else
        _ -> {nil, nil}
      end

    node = %AST.Attribute{
      root: true,
      name: ast_name,
      value: attr_value(name, type, value, attr_meta, compile_meta),
      meta: attr_meta
    }

    process_attributes(mod, attrs, meta, compile_meta, [{name, node} | acc])
  end

  defp process_attributes(mod, [{name, value, attr_meta} | attrs], meta, compile_meta, acc) do
    name = String.to_atom(name)
    attr_meta = Helpers.to_meta(attr_meta, meta)
    {type, type_opts} = Surface.TypeHandler.attribute_type_and_opts(mod, name, attr_meta)

    duplicated_attr? = Keyword.has_key?(acc, name)
    duplicated_html_attr? = !mod && duplicated_attr?

    if duplicated_html_attr? do
      message = """
      the attribute `#{name}` has been passed multiple times on line #{meta.line}. \
      Considering only the last value.

      Hint: remove all redundant definitions
      """

      IOHelper.warn(message, meta.caller, attr_meta.file, attr_meta.line)
    end

    node = %AST.Attribute{
      type: type,
      type_opts: type_opts,
      name: name,
      value: attr_value(name, type, value, attr_meta, compile_meta),
      meta: attr_meta
    }

    process_attributes(mod, attrs, meta, compile_meta, [{name, node} | acc])
  end

  defp attr_value(name, type, {:attribute_expr, value, expr_meta}, attr_meta, _compile_meta) do
    expr_meta = Helpers.to_meta(expr_meta, attr_meta)
    expr = Surface.TypeHandler.expr_to_quoted!(value, name, type, expr_meta)

    AST.AttributeExpr.new(expr, value, expr_meta)
  end

  defp attr_value(_name, _type, {:ast, variable, expr_meta}, _attr_meta, compile_meta) do
    meta = Helpers.to_meta(expr_meta, compile_meta)
    unquote_variable!(variable, compile_meta, meta)
  end

  defp attr_value(name, type, value, meta, _compile_meta) do
    Surface.TypeHandler.literal_to_ast_node!(type, name, value, meta)
  end

  defp validate_tag_children([]), do: :ok

  defp validate_tag_children([%AST.SlotEntry{name: name, meta: meta} | _]) do
    {:error, "slot entries are not allowed as children of HTML elements. Did you mean <##{name} />?", meta}
  end

  defp validate_tag_children([_ | nodes]), do: validate_tag_children(nodes)

  # This is a little bit hacky. :let will only be extracted for the default
  # slot entry if `mod` doesn't export __slot_name__ (i.e. if it isn't a slotable component)
  # we pass in and modify the attributes so that non-slotable components are not
  # processed by the :let directive
  defp collect_slot_entries(mod, attributes, nodes, meta) do
    # Don't extract the slot entry directives if this module is slotable
    {:ok, directives, attributes} =
      if component_slotable?(mod) do
        {:ok, [], attributes}
      else
        collect_directives(@slot_entry_directive_handlers, attributes, meta)
      end

    slot_entries =
      nodes
      |> to_ast(meta)
      |> Enum.group_by(fn
        %AST.SlotEntry{name: name} -> name
        %AST.SlotableComponent{slot: name} -> name
        _ -> :default
      end)

    {already_wrapped, default_children} =
      slot_entries
      |> Map.get(:default, [])
      |> Enum.split_with(fn
        %AST.SlotEntry{} -> true
        _ -> false
      end)

    if Enum.all?(default_children, &Helpers.is_blank_or_empty/1) do
      {:ok, Map.put(slot_entries, :default, already_wrapped), attributes}
    else
      wrapped =
        process_directives(%AST.SlotEntry{
          name: :default,
          children: default_children,
          props: [],
          directives: directives,
          let: nil,
          meta: meta
        })

      {:ok, Map.put(slot_entries, :default, [wrapped | already_wrapped]), attributes}
    end
  end

  defp collect_directives(handlers, attributes, meta) do
    attributes =
      for attr <- attributes,
          attr_name = elem(attr, 0),
          normalized_name = normalize_directive_prefix(attr_name) do
        put_elem(attr, 0, normalized_name)
      end

    do_collect_directives(handlers, attributes, meta)
  end

  for prefix <- @directive_prefixes do
    defp normalize_directive_prefix(unquote(prefix) <> name), do: ":#{name}"
  end

  defp normalize_directive_prefix(name), do: name

  defp do_collect_directives(handlers, attributes, meta)
  defp do_collect_directives(_, [], _), do: {:ok, [], []}

  defp do_collect_directives(handlers, [attr | attributes], meta) do
    {:ok, dirs, attrs} = do_collect_directives(handlers, attributes, meta)

    attr = extract_modifiers(attr)

    directives =
      handlers
      |> Enum.map(fn handler -> handler.extract(attr, meta) end)
      |> List.flatten()

    attributes =
      if Enum.empty?(directives) do
        [attr | attrs]
      else
        attrs
      end

    directives =
      Enum.sort_by(directives ++ dirs, fn %{module: mod} ->
        Enum.find_index(handlers, fn handler -> handler == mod end)
      end)

    {:ok, directives, attributes}
  end

  defp extract_modifiers({":" <> _ = attr_name, value, meta}) do
    {name, modifiers} =
      case String.split(attr_name, ".") do
        [name] ->
          {name, Map.get(meta, :modifiers, [])}

        [name | modifiers] ->
          {name, modifiers}
      end

    {name, value, Map.put(meta, :modifiers, modifiers)}
  end

  defp extract_modifiers(attr) do
    attr
  end

  defp validate_properties(module, props) do
    if function_exported?(module, :__props__, 0) do
      existing_props_names = Enum.map(props, & &1.name)
      required_props_names = module.__required_props_names__()
      missing_props_names = required_props_names -- existing_props_names

      if Enum.any?(missing_props_names) do
        :missing_required_props
      else
        :ok
      end
    end
  end

  defp validate_slot_entries(Surface.Components.Dynamic.Component, _slot_entries, _meta) do
    :ok
  end

  defp validate_slot_entries(Surface.Components.Dynamic.LiveComponent, _slot_entries, _meta) do
    :ok
  end

  defp validate_slot_entries(mod, slot_entries, meta) do
    names = Map.keys(slot_entries)

    if !function_exported?(mod, :__slots__, 0) and not Enum.empty?(names) do
      message = """
      parent component `#{inspect(mod)}` does not define any slots. \
      Found the following slot entries: #{inspect(names)}
      """

      IOHelper.compile_error(message, meta.file, meta.line)
    end

    for name <- mod.__required_slots_names__(),
        !Map.has_key?(slot_entries, name) or
          Enum.all?(Map.get(slot_entries, name, []), &Helpers.is_blank_or_empty/1) do
      message = "missing required slot \"#{name}\" for component <#{meta.node_alias}>"
      IOHelper.warn(message, meta.caller, meta.file, {meta.line, meta.column})
    end

    for {slot_name, slot_entry_instances} <- slot_entries,
        mod.__get_slot__(slot_name) == nil,
        not component_slotable?(mod),
        slot_entry <- slot_entry_instances do
      raise_missing_parent_slot_error!(mod, slot_name, slot_entry.meta, meta)
    end

    :ok
  end

  defp raise_missing_slot_error!(module, slot_name, meta, _defined_slots, true = _default_syntax?) do
    message = """
    no slot `#{slot_name}` defined in the component `#{inspect(module)}`

    Please declare the default slot using `slot default` in order to use the `<#slot />` notation.
    """

    IOHelper.compile_error(message, meta.file, meta.line)
  end

  defp raise_missing_slot_error!(module, slot_name, meta, defined_slots, false = _default_syntax?) do
    defined_slot_names = Enum.map(defined_slots, & &1.name)
    similar_slot_message = similar_slot_message(slot_name, defined_slot_names)
    existing_slots_message = existing_slots_message(defined_slot_names)

    message = """
    no slot `#{slot_name}` defined in the component `#{inspect(module)}`\
    #{similar_slot_message}\
    #{existing_slots_message}\

    Hint: You can define slots using the `slot` macro.\

    For instance: `slot #{slot_name}`\
    """

    IOHelper.compile_error(message, meta.file, meta.line)
  end

  defp raise_missing_parent_slot_error!(mod, slot_name, slot_entry_meta, parent_meta) do
    parent_slots = mod.__slots__() |> Enum.map(& &1.name)

    similar_slot_message = similar_slot_message(slot_name, parent_slots)

    existing_slots_message = existing_slots_message(parent_slots)

    header_message =
      if component_slotable?(slot_entry_meta.module) do
        """
        The slotable component <#{inspect(slot_entry_meta.module)}> has the `:slot` option set to \
        `#{slot_name}`.

        That slot name is not declared in parent component <#{parent_meta.node_alias}>.

        Please declare the slot in the parent component or rename the value in the `:slot` option.\
        """
      else
        """
        no slot "#{slot_name}" defined in parent component <#{parent_meta.node_alias}>\
        """
      end

    message = """
    #{header_message}\
    #{similar_slot_message}\
    #{existing_slots_message}
    """

    IOHelper.compile_error(message, slot_entry_meta.file, slot_entry_meta.line)
  end

  defp raise_complex_generator(meta) do
    message = """
    using `{#else}` is only supported when the expression in `{#for}` has a single generator and no filters.

    Example:

      {#for i <- [1, 2, 3]}
        ...
      {#else}
        ...
      {/for}
    """

    IOHelper.compile_error(message, meta.file, meta.line)
  end

  defp similar_slot_message(slot_name, list_of_slot_names, opts \\ []) do
    threshold = opts[:threshold] || 0.8

    case Helpers.did_you_mean(slot_name, list_of_slot_names) do
      {similar, score} when score > threshold ->
        "\n\nDid you mean #{inspect(to_string(similar))}?"

      _ ->
        ""
    end
  end

  defp existing_slots_message([]), do: ""

  defp existing_slots_message(existing_slots) do
    slots = Enum.map(existing_slots, &to_string/1)
    available = Helpers.list_to_string("slot:", "slots:", slots)
    "\n\nAvailable #{available}"
  end

  defp maybe_warn_required_slot_with_default_value(_, [], _, _), do: nil

  defp maybe_warn_required_slot_with_default_value(slot, _, for_ast, meta) do
    if Keyword.get(slot.opts, :required, false) do
      slot_for_tag = if for_ast == nil, do: "", else: " {#{for_ast.original}}"

      message = """
      setting the fallback content on a required slot has no effect.

      Hint: Either keep the fallback content and remove the `required: true`:

        slot #{slot.name}
        ...
        <#slot#{slot_for_tag}>Fallback content</#slot>

      or keep the slot as required and remove the fallback content:

        slot #{slot.name}, required: true`
        ...
        <#slot#{slot_for_tag} />

      but not both.
      """

      IOHelper.warn(message, meta.caller, meta.file, meta.line)
    end
  end

  defp maybe_warn_argument_for_default_slot_in_slotable_component(slot, arg, meta) do
    if arg && arg.value do
      slot_name = Module.get_attribute(meta.caller.module, :__slot_name__)
      default_slot_of_slotable_component? = slot.name == :default && slot_name

      if default_slot_of_slotable_component? do
        component_name = Macro.to_string(meta.caller.module)

        message = """
        arguments for the default slot in a slotable component are not accessible - instead the arguments \
        from the parent's #{slot_name} slot will be exposed via `:let={...}`.

        Hint: You can remove these arguments, pull them up to the parent component, or make this component not slotable \
        and use it inside an explicit slot entry:
        ```
        <:#{slot_name}>
          <#{component_name} :let={...}>
            ...
          </#{component_name}>
        </:#{slot_name}>
        ```
        """

        IOHelper.warn(message, meta.caller, meta.line)
      end
    end
  end

  defp unquote_variable!(variable, compile_meta, expr_meta) do
    validate_inside_quote_surface!(compile_meta, expr_meta)
    validate_variable!(variable, expr_meta)

    case fetch_variable_value!(variable, compile_meta, expr_meta) do
      value when is_binary(value) or is_boolean(value) or is_integer(value) ->
        %Surface.AST.Literal{value: value}

      [value] ->
        value

      value when is_list(value) ->
        %AST.Container{children: value, meta: expr_meta}

      ast ->
        ast
    end
  end

  defp validate_inside_quote_surface!(compile_meta, expr_meta) do
    if !compile_meta.variables do
      message = "cannot use tagged expression {^var} outside `quote_surface`"
      IOHelper.compile_error(message, expr_meta.file, expr_meta.line)
    end
  end

  defp validate_variable!(variable, expr_meta) do
    if !Regex.match?(~r/^[a-z][a-zA-Z_\d]*$/, variable) do
      message = """
      cannot unquote `#{variable}`.

      The expression to be unquoted must be written as `^var`, where `var` is an existing variable.
      """

      IOHelper.compile_error(message, expr_meta.file, expr_meta.line)
    end
  end

  defp fetch_variable_value!(variable, compile_meta, expr_meta) do
    case Keyword.fetch(compile_meta.variables, String.to_atom(variable)) do
      :error ->
        defined_variables = compile_meta.variables |> Keyword.keys() |> Enum.map(&to_string/1)

        similar_variable_message =
          case Helpers.did_you_mean(variable, defined_variables) do
            {similar, score} when score > 0.8 ->
              "\n\nDid you mean #{inspect(to_string(similar))}?"

            _ ->
              ""
          end

        available_variables =
          Helpers.list_to_string(
            "\n\nAvailable variable:",
            "\n\nAvailable variables:",
            defined_variables
          )

        message = """
        undefined variable "#{variable}".#{similar_variable_message}#{available_variables}
        """

        IOHelper.compile_error(message, expr_meta.file, expr_meta.line)

      {:ok, value} ->
        value
    end
  end

  defp validate_slot_attrs!(attrs, caller) do
    Enum.each(attrs, &validate_slot_attr!(&1, caller))
  end

  defp validate_slot_attr!({name, _, _meta}, _caller) when name in @valid_slot_props do
    :ok
  end

  defp validate_slot_attr!({name, _, %{file: file, line: line}}, _caller) do
    type =
      case name do
        ":" <> _ -> "directive"
        _ -> "attribute"
      end

    message = """
    invalid #{type} `#{name}` for <#slot>.

    Slots only accept the root prop, `generator_value`, `:if` and `:for`.
    """

    IOHelper.compile_error(message, file, line)
  end

  defp handle_convert_node_to_ast_error(name, error, meta) do
    case error do
      {:error, message, details} ->
        {:error, {"cannot render <#{name}> (#{message})", details, meta.line, meta.column}, meta}

      {:error, message} ->
        {:error, {"cannot render <#{name}> (#{message})", meta.line, meta.column}, meta}

      _ ->
        {:error, {"cannot render <#{name}>", meta.line, meta.column}, meta}
    end
  end

  defp maybe_transform_ast(nodes, %CompileMeta{style: style, caller: caller, caller_spec: caller_spec}) do
    Enum.map(nodes, fn node ->
      node
      |> maybe_add_s_scope_to_root_node(caller_spec)
      |> maybe_add_s_self_to_root_node(caller_spec)
      |> maybe_add_vars_to_style_attr_on_root(style, caller.function)
      |> maybe_add_caller_scope_id_attr_to_root_node(caller_spec)
      |> maybe_add_data_variants_to_root_node(caller_spec)
    end)
  end

  defp maybe_transform_ast(nodes, _compile_meta) do
    nodes
  end

  defp maybe_add_s_self_to_root_node(%AST.Tag{} = node, %CallerSpec{requires_s_self_on_root?: true}) do
    %AST.Tag{attributes: attributes, meta: meta} = node

    data_self_attr = %AST.Attribute{
      meta: meta,
      name: :"#{CSSTranslator.self_attr()}",
      type: :string,
      value: %AST.Literal{value: true}
    }

    %AST.Tag{node | attributes: [data_self_attr | attributes]}
  end

  defp maybe_add_s_self_to_root_node(node, _caller_spec) do
    node
  end

  defp maybe_add_s_scope_to_root_node(
         %AST.Tag{} = node,
         %CallerSpec{requires_s_scope_on_root?: true} = caller_spec
       ) do
    %AST.Tag{attributes: attributes, meta: meta} = node

    data_s_scope = :"#{CSSTranslator.scope_attr_prefix()}#{caller_spec.scope_id}"

    attributes =
      if not AST.has_attribute?(attributes, data_s_scope) do
        data_scope_attr = %AST.Attribute{
          meta: meta,
          name: data_s_scope,
          type: :string,
          value: %AST.Literal{value: true}
        }

        [data_scope_attr | attributes]
      else
        attributes
      end

    %AST.Tag{node | attributes: attributes}
  end

  defp maybe_add_s_scope_to_root_node(node, _caller_spec) do
    node
  end

  defp maybe_add_vars_to_style_attr_on_root(%AST.Tag{} = node, %{vars: vars, inline?: inline?} = style, func)
       when vars != %{} and (func == {:render, 1} or inline?) do
    %AST.Tag{attributes: attributes, meta: meta} = node
    %{file: file} = style

    vars_ast =
      for {var, {expr, %{line: line, column: column}}} <- vars do
        # +1 for the parenthesis, +1 for the quote
        col = column + 2
        {String.to_atom(var), Code.string_to_quoted!(expr, line: line, column: col, file: file)}
      end

    updated_attrs =
      case AST.pop_attributes_as_map(attributes, [:style]) do
        {%{style: nil}, rest} ->
          attr = %AST.Attribute{
            meta: meta,
            name: :style,
            type: :style,
            value: %AST.AttributeExpr{
              meta: meta,
              value: vars_ast
            }
          }

          [attr | rest]

        {%{style: %AST.Attribute{value: value} = style}, rest} ->
          style_expr = merge_vars_into_style(value, vars_ast, meta)
          [%AST.Attribute{style | value: style_expr} | rest]
      end

    %AST.Tag{node | attributes: updated_attrs}
  end

  defp maybe_add_vars_to_style_attr_on_root(node, _style, _func) do
    node
  end

  defp maybe_add_data_variants_to_root_node(%AST.Tag{} = node, caller_spec) do
    %AST.Tag{attributes: attributes, meta: meta} = node
    %CallerSpec{data_variants: data_variants} = caller_spec

    variants_attributes =
      for {type, _func, _name, data_name, assign_ast, _variants} <- data_variants do
        expr_ast =
          case type do
            :boolean ->
              quote do
                unquote(assign_ast) == true
              end

            :enum ->
              quote do
                unquote(assign_ast) != nil and not Enum.empty?(unquote(assign_ast))
              end

            :choice ->
              quote do
                unquote(assign_ast)
              end

            :other ->
              quote do
                unquote(assign_ast) != nil
              end
          end

        %AST.Attribute{
          meta: meta,
          name: "data-#{data_name}",
          type: :string,
          value: %AST.AttributeExpr{
            meta: meta,
            value: expr_ast
          }
        }
      end

    %AST.Tag{node | attributes: variants_attributes ++ attributes}
  end

  defp maybe_add_data_variants_to_root_node(node, _style) do
    node
  end

  defp merge_vars_into_style(%AST.AttributeExpr{value: attr_expr_value} = attr_expr, vars_ast, _meta) do
    {p1, p2, [p3, p4, p5, value, p6, p7, p8]} = attr_expr_value

    %AST.AttributeExpr{attr_expr | constant?: false, value: {p1, p2, [p3, p4, p5, value ++ vars_ast, p6, p7, p8]}}
  end

  defp merge_vars_into_style(%AST.Literal{value: value}, vars_ast, meta) do
    {:ok, kw_list} = Surface.TypeHandler.Style.expr_to_value([value], [], nil)

    %AST.AttributeExpr{
      meta: meta,
      original: value,
      value: kw_list ++ vars_ast
    }
  end

  defp maybe_transform_tag(node, %mod{
         style: style,
         caller_spec: %CallerSpec{has_style_or_variants?: true} = caller_spec
       })
       when mod in [CompileMeta, AST.Meta] do
    %{element: element, attributes: attributes, meta: meta} = node
    %{selectors: selectors} = style
    %CallerSpec{scope_id: scope_id, variants: variants} = caller_spec

    if universal_in_selectors?(selectors) or
         element_in_selectors?(element, selectors) or
         maybe_in_selectors_or_using_variants?(element, attributes, selectors, variants) do
      s_data_attr = %AST.Attribute{
        meta: meta,
        name: :"#{CSSTranslator.scope_attr_prefix()}#{scope_id}",
        type: :string,
        value: %AST.Literal{value: true}
      }

      %{node | attributes: [s_data_attr | attributes]}
    else
      node
    end
  end

  defp maybe_transform_tag(node, _compile_meta) do
    node
  end

  defp maybe_in_selectors_or_using_variants?(element, attributes, selectors, variants) do
    {%{id: id, class: class}, _} = AST.pop_attributes_values_as_map(attributes, [:id, :class])

    maybe_in_class_selectors_or_variants?(element, class, selectors, variants) or
      maybe_in_id_selectors?(element, id, selectors) or
      maybe_in_combined_selectors?(element, id, class, selectors)
  end

  defp maybe_in_class_selectors_or_variants?(element, class, %{classes: classes, combined: combined}, variants) do
    case class do
      %AST.Literal{value: value} ->
        value
        |> String.split()
        |> Enum.any?(fn c ->
          MapSet.member?(classes, c) or
            MapSet.member?(combined, MapSet.new([element, ".#{c}"])) or
            String.contains?(c, variants)
        end)

      nil ->
        false

      _ ->
        true
    end
  end

  defp maybe_in_combined_selectors?(_, %AST.AttributeExpr{} = _id, _, _) do
    true
  end

  defp maybe_in_combined_selectors?(_, _, %AST.AttributeExpr{} = _class, _) do
    true
  end

  defp maybe_in_combined_selectors?(element, id, class, %{combined: combined}) do
    sels =
      case class do
        %AST.Literal{value: value} -> value |> String.split() |> Enum.map(&".#{&1}")
        _ -> []
      end

    sels =
      case id do
        %AST.Literal{value: value} -> [value | sels]
        _ -> sels
      end

    sels_set = MapSet.new([element | sels])

    Enum.any?(combined, &MapSet.subset?(&1, sels_set))
  end

  defp maybe_in_id_selectors?(element, id, %{ids: ids, combined: combined}) do
    case id do
      %AST.Literal{value: value} ->
        MapSet.member?(ids, value) or MapSet.member?(combined, MapSet.new([element, "##{value}"]))

      nil ->
        false

      _ ->
        true
    end
  end

  defp element_in_selectors?(element, %{elements: elements}) do
    MapSet.member?(elements, element)
  end

  defp universal_in_selectors?(%{other: other}) do
    MapSet.member?(other, "*")
  end

  defp maybe_pop_style([{"style", _attrs, content, %{line: line}} | tokens], %{function: fun} = caller, opts)
       when fun != nil do
    style =
      content
      |> to_string()
      |> CSSTranslator.translate!(
        line: line,
        file: opts[:file],
        inline?: true,
        scope: {caller.module, elem(caller.function, 0)}
      )

    if not Module.has_attribute?(caller.module, :__style__) do
      Module.register_attribute(caller.module, :__style__, accumulate: true)
    end

    Module.put_attribute(caller.module, :__style__, {elem(caller.function, 0), style})

    {style, tokens}
  end

  defp maybe_pop_style(tokens, caller, _opts) do
    style =
      if Module.open?(caller.module) && caller.function do
        caller.module
        |> Helpers.get_module_attribute(:__style__, [])
        |> Keyword.get(:__module__)
      end

    # TODO: Create a struct to hold and inicialize the selectors or even the style itself
    style =
      style ||
        %{
          scope_id: Surface.Compiler.CSSTranslator.scope_id(caller.module),
          selectors: %{
            elements: MapSet.new(),
            classes: MapSet.new(),
            ids: MapSet.new(),
            combined: MapSet.new(),
            other: MapSet.new()
          }
        }

    {style, tokens}
  end

  defp skip_blanks([]) do
    []
  end

  defp skip_blanks([token | rest] = tokens) do
    if Helpers.blank?(token) do
      skip_blanks(rest)
    else
      tokens
    end
  end
end
