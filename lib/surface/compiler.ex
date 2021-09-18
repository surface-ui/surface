defmodule Surface.Compiler do
  @moduledoc """
  Defines a behaviour that must be implemented by all HTML/Surface node translators.

  This module also contains the main logic to translate Surface code.
  """

  alias Surface.Compiler.Parser
  alias Surface.IOHelper
  alias Surface.AST
  alias Surface.Compiler.Helpers

  @stateful_component_types [
    Surface.LiveComponent
  ]

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

  @template_directive_handlers [Surface.Directive.Let]

  @slot_directive_handlers [
    Surface.Directive.SlotArgs,
    Surface.Directive.If,
    Surface.Directive.For
  ]

  @valid_slot_props ["name", "index"]

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

  defmodule CompileMeta do
    defstruct [:line, :file, :caller, :checks, :variables]

    @type t :: %__MODULE__{
            line: non_neg_integer(),
            file: binary(),
            caller: Macro.Env.t(),
            variables: keyword(),
            checks: Keyword.t(boolean())
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
    compile_meta = %CompileMeta{
      line: line,
      file: file,
      caller: caller,
      checks: opts[:checks] || [],
      variables: opts[:variables]
    }

    string
    |> Parser.parse!(
      file: file,
      line: line,
      caller: caller,
      checks: opts[:checks] || [],
      warnings: opts[:warnings] || [],
      column: Keyword.get(opts, :column, 1),
      indentation: Keyword.get(opts, :indentation, 0)
    )
    |> to_ast(compile_meta)
    |> validate_component_structure(compile_meta, caller.module)
  end

  def to_live_struct(nodes, opts \\ []) do
    Surface.Compiler.EExEngine.translate(nodes, opts)
  end

  def validate_component_structure(ast, meta, module) do
    if is_stateful_component(module) do
      validate_stateful_component(ast, meta)
    end

    ast
  end

  defp is_stateful_component(module) do
    cond do
      function_exported?(module, :component_type, 0) ->
        module.component_type() in @stateful_component_types

      Module.open?(module) ->
        # If the template is compiled directly in a test module, get_attribute might fail,
        # breaking some of the tests once in a while.
        try do
          Module.get_attribute(module, :component_type) in @stateful_component_types
        rescue
          _e in ArgumentError -> false
        end

      true ->
        false
    end
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

        {:error, {message, line}, meta} ->
          IOHelper.warn(message, compile_meta.caller, meta.file, line)
          %AST.Error{message: message, meta: meta}

        {:error, {message, details, line}, meta} ->
          details = if details, do: "\n\n" <> details, else: ""
          IOHelper.warn(message <> details, compile_meta.caller, meta.file, line)
          %AST.Error{message: message, meta: meta}
      end
    end
  end

  # Slots
  defp node_type({"#template", _, _, _}), do: :template
  defp node_type({"#slot", _, _, _}), do: :slot
  defp node_type({":" <> _, _, _, _}), do: :template
  defp node_type({"slot", _, _, _}), do: :slot

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
    directives
    |> Enum.filter(fn %AST.Directive{module: mod} -> function_exported?(mod, :process, 2) end)
    |> Enum.reduce(node, fn %AST.Directive{module: mod} = directive, node ->
      mod.process(directive, node)
    end)
  end

  defp process_directives(node), do: node

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

  defp convert_node_to_ast(:template, {name, attributes, children, node_meta}, compile_meta) do
    meta = Helpers.to_meta(node_meta, compile_meta)

    with {:ok, directives, attributes} <-
           collect_directives(@template_directive_handlers, attributes, meta),
         slot <- get_slot_name(name, attributes) do
      {:ok,
       %AST.Template{
         name: slot,
         children: to_ast(children, compile_meta),
         directives: directives,
         let: [],
         meta: meta
       }}
    else
      _ -> {:error, {"failed to parse template", meta.line}, meta}
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

    # TODO: Validate attributes with custom messages
    name = attribute_value(attributes, "name", :default)
    short_slot_syntax? = not has_attribute?(attributes, "name")

    index = attribute_value_as_ast(attributes, "index", %Surface.AST.Literal{value: 0}, compile_meta)

    with {:ok, directives, attrs} <-
           collect_directives(@slot_directive_handlers, attributes, meta),
         slot <- Enum.find(defined_slots, fn slot -> slot.name == name end),
         slot when not is_nil(slot) <- slot do
      maybe_warn_required_slot_with_default_value(slot, children, short_slot_syntax?, meta)
      validate_slot_attrs!(attrs)

      {:ok,
       %AST.Slot{
         name: name,
         index: index,
         directives: directives,
         default: to_ast(children, compile_meta),
         args: [],
         meta: meta
       }}
    else
      _ ->
        raise_missing_slot_error!(
          meta.caller.module,
          name,
          meta,
          defined_slots,
          short_slot_syntax?
        )
    end
  end

  defp convert_node_to_ast(:tag, {name, attributes, children, node_meta}, compile_meta) do
    meta = Helpers.to_meta(node_meta, compile_meta)

    with {:ok, directives, attributes} <-
           collect_directives(@tag_directive_handlers, attributes, meta),
         attributes <- process_attributes(nil, attributes, meta, compile_meta),
         children <- to_ast(children, compile_meta),
         :ok <- validate_tag_children(children) do
      {:ok,
       %AST.Tag{
         element: name,
         attributes: attributes,
         directives: directives,
         children: children,
         meta: meta
       }}
    else
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
       %AST.VoidTag{
         element: name,
         attributes: attributes,
         directives: directives,
         meta: meta
       }}
    else
      error -> handle_convert_node_to_ast_error(name, error, meta)
    end
  end

  defp convert_node_to_ast(:function_component, node, compile_meta) do
    {name, attributes, children, %{decomposed_tag: {type, mod, fun}} = node_meta} = node

    meta =
      node_meta
      |> Helpers.to_meta(compile_meta)
      |> Map.merge(%{module: mod, node_alias: name, function_component?: true})

    with {:ok, templates, attributes} <- collect_templates(mod, attributes, children, meta),
         {:ok, directives, attributes} <- collect_directives(@component_directive_handlers, attributes, meta),
         attributes <- process_attributes(nil, attributes, meta, compile_meta) do
      ast = %AST.FunctionComponent{
        module: mod,
        fun: fun,
        type: type,
        props: attributes,
        directives: directives,
        templates: templates,
        meta: meta
      }

      {:ok, ast}
    else
      error -> handle_convert_node_to_ast_error(name, error, meta)
    end
  end

  # Recursive components must be represented as function components
  # until we can validate templates and properties of open modules
  defp convert_node_to_ast(:recursive_component, node, compile_meta) do
    {name, attributes, children, %{decomposed_tag: {_, mod, _}} = node_meta} = node

    meta =
      node_meta
      |> Helpers.to_meta(compile_meta)
      |> Map.merge(%{module: mod, node_alias: name})

    # TODO: we should call validate_templates/3 and validate_properties/4 validate
    # based on the module attributes since the module is still open
    with component_type <- Module.get_attribute(mod, :component_type),
         true <- component_type != nil,
         # This is a little bit hacky. :let will only be extracted for the default
         # template if `mod` doesn't export __slot_name__ (i.e. if it isn't a slotable component)
         # we pass in and modify the attributes so that non-slotable components are not
         # processed by the :let directive
         {:ok, templates, attributes} <- collect_templates(mod, attributes, children, meta),
         {:ok, directives, attributes} <- collect_directives(@component_directive_handlers, attributes, meta),
         attributes <- process_attributes(nil, attributes, meta, compile_meta) do
      ast = %AST.FunctionComponent{
        module: mod,
        fun: :render,
        type: :remote,
        props: attributes,
        directives: directives,
        templates: templates,
        meta: meta
      }

      {:ok, maybe_call_transform(ast)}
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
         # template if `mod` doesn't export __slot_name__ (i.e. if it isn't a slotable component)
         # we pass in and modify the attributes so that non-slotable components are not
         # processed by the :let directive
         {:ok, templates, attributes} <- collect_templates(mod, attributes, children, meta),
         :ok <- validate_templates(mod, templates, meta),
         {:ok, directives, attributes} <- collect_directives(@component_directive_handlers, attributes, meta),
         attributes <- process_attributes(mod, attributes, meta, compile_meta),
         :ok <- validate_properties(mod, attributes, directives, meta) do
      result =
        if component_slotable?(mod) do
          %AST.SlotableComponent{
            module: mod,
            slot: mod.__slot_name__(),
            type: component_type,
            let: [],
            props: attributes,
            directives: directives,
            templates: templates,
            meta: meta
          }
        else
          %AST.Component{
            module: mod,
            type: component_type,
            props: attributes,
            directives: directives,
            templates: templates,
            meta: meta
          }
        end

      {:ok, maybe_call_transform(result)}
    else
      error -> handle_convert_node_to_ast_error(name, error, meta)
    end
  end

  defp convert_node_to_ast(:macro_component, {"#" <> name, attributes, children, node_meta}, compile_meta) do
    meta = Helpers.to_meta(node_meta, compile_meta)
    mod = Helpers.actual_component_module!(name, meta.caller)
    meta = Map.merge(meta, %{module: mod, node_alias: name})

    with :ok <- Helpers.validate_component_module(mod, name),
         meta <- Map.merge(meta, %{module: mod, node_alias: name}),
         true <- function_exported?(mod, :expand, 3),
         {:ok, directives, attributes} <-
           collect_directives(@meta_component_directive_handlers, attributes, meta),
         attributes <- process_attributes(mod, attributes, meta, compile_meta),
         :ok <- validate_properties(mod, attributes, directives, meta) do
      compile_dep_expr = %AST.Expr{
        value:
          quote generated: true, line: meta.line do
            require(unquote(mod)).__compile_dep__()
          end,
        meta: meta
      }

      expanded_children = mod.expand(attributes, List.to_string(children), meta)
      children_with_dep = [compile_dep_expr | List.wrap(expanded_children)]

      {:ok, %AST.Container{children: children_with_dep, directives: directives, meta: meta}}
    else
      false ->
        {:error, {"cannot render <#{name}> (MacroComponents must export an expand/3 function)", meta.line}, meta}

      error ->
        handle_convert_node_to_ast_error(name, error, meta)
    end
  end

  defp maybe_call_transform(%{module: module} = node) do
    if function_exported?(module, :transform, 1) do
      module.transform(node)
    else
      node
    end
  end

  defp attribute_value(attributes, attr_name, default) do
    Enum.find_value(attributes, default, fn {name, value, _} ->
      if name == attr_name do
        String.to_atom(value)
      end
    end)
  end

  defp has_attribute?([], _), do: false

  defp has_attribute?(attributes, attr_name),
    do: Enum.any?(attributes, &match?({^attr_name, _, _}, &1))

  defp attribute_value_as_ast(attributes, attr_name, type \\ :integer, default, meta) do
    Enum.find_value(attributes, default, fn
      {^attr_name, {:attribute_expr, value, expr_meta}, _attr_meta} ->
        expr_meta = Helpers.to_meta(expr_meta, meta)
        expr = Surface.TypeHandler.expr_to_quoted!(value, attr_name, type, expr_meta)

        AST.AttributeExpr.new(expr, value, expr_meta)

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

  defp get_slot_name("#template", attributes), do: attribute_value(attributes, "slot", :default)
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
    with true <- function_exported?(mod, :__props__, 0),
         prop when not is_nil(prop) <- Enum.find(mod.__props__(), & &1.opts[:root]) do
      name = Atom.to_string(prop.name)
      process_attributes(mod, [{name, value, attr_meta} | attrs], meta, compile_meta, acc)
    else
      _ ->
        message = """
        no root property defined for component <#{meta.node_alias}>

        Hint: you can declare a root property using option `root: true`
        """

        IOHelper.warn(message, meta.caller, attr_meta.file, attr_meta.line)
        process_attributes(mod, attrs, meta, compile_meta, acc)
    end
  end

  defp process_attributes(mod, [{name, value, attr_meta} | attrs], meta, compile_meta, acc) do
    name = String.to_atom(name)
    attr_meta = Helpers.to_meta(attr_meta, meta)
    {type, type_opts} = Surface.TypeHandler.attribute_type_and_opts(mod, name, attr_meta)

    duplicated_attr? = Keyword.has_key?(acc, name)
    duplicated_prop? = mod && (!Keyword.get(type_opts, :accumulate, false) and duplicated_attr?)
    duplicated_html_attr? = !mod && duplicated_attr?
    root_prop? = Keyword.get(type_opts, :root, false)

    cond do
      duplicated_prop? && root_prop? ->
        message = """
        the prop `#{name}` has been passed multiple times. Considering only the last value.

        Hint: Either specify the `#{name}` via the root property (`<#{meta.node_alias} { ... }>`) or \
        explicitly via the #{name} property (`<#{meta.node_alias} #{name}="...">`), but not both.
        """

        IOHelper.warn(message, meta.caller, attr_meta.file, attr_meta.line)

      duplicated_prop? && not root_prop? ->
        message = """
        the prop `#{name}` has been passed multiple times. Considering only the last value.

        Hint: Either remove all redundant definitions or set option `accumulate` to `true`:

        ```
          prop #{name}, :#{type}, accumulate: true
        ```

        This way the values will be accumulated in a list.
        """

        IOHelper.warn(message, meta.caller, attr_meta.file, attr_meta.line)

      duplicated_html_attr? ->
        message = """
        the attribute `#{name}` has been passed multiple times on line #{meta.line}. \
        Considering only the last value.

        Hint: remove all redundant definitions
        """

        IOHelper.warn(message, meta.caller, attr_meta.file, attr_meta.line)

      true ->
        nil
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

  defp validate_tag_children([%AST.Template{name: name} | _]) do
    {:error, "templates are only allowed as children elements of components, but found template for #{name}"}
  end

  defp validate_tag_children([_ | nodes]), do: validate_tag_children(nodes)

  # This is a little bit hacky. :let will only be extracted for the default
  # template if `mod` doesn't export __slot_name__ (i.e. if it isn't a slotable component)
  # we pass in and modify the attributes so that non-slotable components are not
  # processed by the :let directive
  defp collect_templates(mod, attributes, nodes, meta) do
    # Don't extract the template directives if this module is slotable
    {:ok, directives, attributes} =
      if component_slotable?(mod) do
        {:ok, [], attributes}
      else
        collect_directives(@template_directive_handlers, attributes, meta)
      end

    templates =
      nodes
      |> to_ast(meta)
      |> Enum.group_by(fn
        %AST.Template{name: name} -> name
        %AST.SlotableComponent{slot: name} -> name
        _ -> :default
      end)

    {already_wrapped, default_children} =
      templates
      |> Map.get(:default, [])
      |> Enum.split_with(fn
        %AST.Template{} -> true
        _ -> false
      end)

    if Enum.all?(default_children, &Helpers.is_blank_or_empty/1) do
      {:ok, Map.put(templates, :default, already_wrapped), attributes}
    else
      wrapped =
        process_directives(%AST.Template{
          name: :default,
          children: default_children,
          directives: directives,
          let: [],
          meta: meta
        })

      {:ok, Map.put(templates, :default, [wrapped | already_wrapped]), attributes}
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

  defp validate_properties(module, props, directives, meta) do
    has_directive_props? = Enum.any?(directives, &match?(%AST.Directive{name: :props}, &1))

    if not has_directive_props? and function_exported?(module, :__props__, 0) do
      existing_props_names = Enum.map(props, & &1.name)
      required_props_names = module.__required_props_names__()
      missing_props_names = required_props_names -- existing_props_names

      for prop_name <- missing_props_names do
        message = "Missing required property \"#{prop_name}\" for component <#{meta.node_alias}>"

        message =
          if prop_name == :id and is_stateful_component(module) do
            message <>
              """
              \n\nHint: Components using `Surface.LiveComponent` automatically define a required `id` prop to make them stateful.
              If you meant to create a stateless component, you can switch to `use Surface.Component`.
              """
          else
            message
          end

        IOHelper.warn(message, meta.caller, meta.file, meta.line)
      end
    end

    :ok
  end

  defp validate_templates(Surface.Components.Dynamic.Component, _templates, _meta) do
    :ok
  end

  defp validate_templates(mod, templates, meta) do
    names = Map.keys(templates)

    if !function_exported?(mod, :__slots__, 0) and not Enum.empty?(names) do
      message = """
      parent component `#{inspect(mod)}` does not define any slots. \
      Found the following templates: #{inspect(names)}
      """

      IOHelper.compile_error(message, meta.file, meta.line)
    end

    for name <- mod.__required_slots_names__(),
        !Map.has_key?(templates, name) or
          Enum.all?(Map.get(templates, name, []), &Helpers.is_blank_or_empty/1) do
      message = "missing required slot \"#{name}\" for component <#{meta.node_alias}>"
      IOHelper.warn(message, meta.caller, meta.file, meta.line)
    end

    for {slot_name, template_instances} <- templates,
        mod.__get_slot__(slot_name) == nil,
        not component_slotable?(mod),
        template <- template_instances do
      raise_missing_parent_slot_error!(mod, slot_name, template.meta, meta)
    end

    for slot_name <- Map.keys(templates),
        template <- Map.get(templates, slot_name) do
      slot = mod.__get_slot__(slot_name)
      args = Keyword.keys(template.let)

      arg_meta =
        Enum.find_value(template.directives, meta, fn directive ->
          if directive.module == Surface.Directive.Let do
            directive.meta
          end
        end)

      case slot do
        %{opts: opts} ->
          non_generator_args = Enum.map(opts[:args] || [], &Map.get(&1, :name))

          undefined_keys = args -- non_generator_args

          if not Enum.empty?(undefined_keys) do
            [arg | _] = undefined_keys

            message = """
            undefined argument `#{inspect(arg)}` for slot `#{slot_name}` in `#{inspect(mod)}`.

            Available arguments: #{inspect(non_generator_args)}.

            Hint: You can define a new slot argument using the `args` option: \
            `slot #{slot_name}, args: [..., #{inspect(arg)}]`
            """

            IOHelper.compile_error(message, arg_meta.file, arg_meta.line)
          end

        _ ->
          :ok
      end
    end

    :ok
  end

  defp raise_missing_slot_error!(module, slot_name, meta, _defined_slots, true = _short_syntax?) do
    message = """
    no slot `#{slot_name}` defined in the component `#{inspect(module)}`

    Please declare the default slot using `slot default` in order to use the `<#slot />` notation.
    """

    IOHelper.compile_error(message, meta.file, meta.line)
  end

  defp raise_missing_slot_error!(module, slot_name, meta, defined_slots, false = _short_syntax?) do
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

  defp raise_missing_parent_slot_error!(mod, slot_name, template_meta, parent_meta) do
    parent_slots = mod.__slots__() |> Enum.map(& &1.name)

    similar_slot_message = similar_slot_message(slot_name, parent_slots)

    existing_slots_message = existing_slots_message(parent_slots)

    header_message =
      if component_slotable?(template_meta.module) do
        """
        The slotable component <#{inspect(template_meta.module)}> as the `:slot` option set to \
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

    IOHelper.compile_error(message, template_meta.file, template_meta.line)
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

  defp maybe_warn_required_slot_with_default_value(slot, _, short_syntax?, meta) do
    if Keyword.get(slot.opts, :required, false) do
      slot_name_tag = if short_syntax?, do: "", else: " name=\"#{slot.name}\""

      message = """
      setting the fallback content on a required slot has no effect.

      Hint: Either keep the fallback content and remove the `required: true`:

        slot #{slot.name}
        ...
        <#slot#{slot_name_tag}>Fallback content</#slot>

      or keep the slot as required and remove the fallback content:

        slot #{slot.name}, required: true`
        ...
        <#slot#{slot_name_tag} />

      but not both.
      """

      IOHelper.warn(message, meta.caller, meta.file, meta.line)
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

  defp validate_slot_attrs!(attrs) do
    Enum.each(attrs, &validate_slot_attr!/1)
  end

  defp validate_slot_attr!({name, _, _meta}) when name in @valid_slot_props do
    :ok
  end

  defp validate_slot_attr!({name, _, %{file: file, line: line}}) do
    type =
      case name do
        ":" <> _ -> "directive"
        _ -> "attribute"
      end

    message = """
    invalid #{type} `#{name}` for <#slot>.

    Slots only accept `name`, `index`, `:args`, `:if` and `:for`.
    """

    IOHelper.compile_error(message, file, line)
  end

  defp handle_convert_node_to_ast_error(name, error, meta) do
    case error do
      {:error, message, details} ->
        {:error, {"cannot render <#{name}> (#{message})", details, meta.line}, meta}

      {:error, message} ->
        {:error, {"cannot render <#{name}> (#{message})", meta.line}, meta}

      _ ->
        {:error, {"cannot render <#{name}>", meta.line}, meta}
    end
  end
end
