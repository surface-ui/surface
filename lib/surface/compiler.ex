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
    Surface.Directive.If,
    Surface.Directive.For,
    Surface.Directive.Debug,
    Surface.Directive.Hook
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
    Surface.Directive.SlotProps,
    Surface.Directive.If,
    Surface.Directive.For
  ]

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

  defmodule ParseError do
    defexception file: "", line: 0, message: "error parsing HTML/Surface"

    @impl true
    def message(exception) do
      "#{Path.relative_to_cwd(exception.file)}:#{exception.line}: #{exception.message}"
    end
  end

  defmodule CompileMeta do
    defstruct [:line_offset, :file, :caller, :checks]

    @type t :: %__MODULE__{
            line_offset: non_neg_integer(),
            file: binary(),
            caller: Macro.Env.t(),
            checks: Keyword.t(boolean())
          }
  end

  @doc """
  This function compiles a string into the Surface AST.This is used by ~H and Surface.Renderer to parse and compile templates.

  A special note for line_offset: This is considered the line number for the first line in the string. If the first line of the
  string is also the first line of the file, then this should be 1. If this is being called within a macro (say to process a heredoc
  passed to ~H), this should be __CALLER__.line + 1.
  """
  @spec compile(binary, non_neg_integer(), Macro.Env.t(), binary(), Keyword.t()) :: [
          Surface.AST.t()
        ]
  def compile(string, line_offset, caller, file \\ "nofile", opts \\ []) do
    compile_meta = %CompileMeta{
      line_offset: line_offset,
      file: file,
      caller: caller,
      checks: opts[:checks] || []
    }

    string
    |> Parser.parse()
    |> case do
      {:ok, nodes} ->
        nodes

      {:error, message, line} ->
        raise %ParseError{line: line + line_offset - 1, file: file, message: message}
    end
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
    if Module.open?(module) do
      Module.get_attribute(module, :component_type, Surface.BaseComponent) in @stateful_component_types
    else
      function_exported?(module, :component_type, 0) and
        module.component_type() in @stateful_component_types
    end
  end

  defp validate_stateful_component(ast, %CompileMeta{
         line_offset: offset,
         caller: %{function: {:render, _}} = caller
       }) do
    num_tags =
      ast
      |> Enum.filter(fn
        %AST.Tag{} ->
          true

        %AST.VoidTag{} ->
          true

        %AST.Component{type: Surface.LiveComponent, meta: meta} ->
          warn_live_component_as_root_node_of_another_live_component(meta, caller, offset)

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
          caller,
          fn _ -> offset end
        )

      num_tags > 1 ->
        IOHelper.warn(
          "stateful live components must have a single HTML root element",
          caller,
          fn _ -> offset end
        )

      true ->
        :noop
    end
  end

  defp validate_stateful_component(_ast, %CompileMeta{}), do: nil

  defp warn_live_component_as_root_node_of_another_live_component(meta, caller, offset) do
    IOHelper.warn(
      """
      cannot have a LiveComponent as root node of another LiveComponent.

      Hint: You can wrap the root `#{meta.node_alias}` node in another element. Example:

        def render(assigns) do
          ~H"\""
          <div>
            <#{meta.node_alias} ... >
              ...
            </#{meta.node_alias}>
          </div>
          "\""
        end
      """,
      caller,
      fn _ -> offset end
    )
  end

  defp to_ast(nodes, compile_meta) do
    for node <- nodes do
      case convert_node_to_ast(node_type(node), node, compile_meta) do
        {:ok, ast} ->
          process_directives(ast)

        {:error, {message, line}, meta} ->
          IOHelper.warn(message, compile_meta.caller, fn _ -> line end)
          %AST.Error{message: message, meta: meta}

        {:error, {message, details, line}, meta} ->
          details = if details, do: "\n\n" <> details, else: ""
          IOHelper.warn(message <> details, compile_meta.caller, fn _ -> line end)
          %AST.Error{message: message, meta: meta}
      end
    end
  end

  defp node_type({"#" <> _, _, _, _}), do: :macro_component
  defp node_type({<<first, _::binary>>, _, _, _}) when first in ?A..?Z, do: :component
  defp node_type({"template", _, _, _}), do: :template
  defp node_type({"slot", _, _, _}), do: :slot
  defp node_type({name, _, _, _}) when name in @void_elements, do: :void_tag
  defp node_type({_, _, _, _}), do: :tag
  defp node_type({:interpolation, _, _}), do: :interpolation
  defp node_type(_), do: :text

  defp process_directives(%{directives: directives} = node) do
    directives
    |> Enum.filter(fn %AST.Directive{module: mod} -> function_exported?(mod, :process, 2) end)
    |> Enum.reduce(node, fn %AST.Directive{module: mod} = directive, node ->
      mod.process(directive, node)
    end)
  end

  defp process_directives(node), do: node

  defp convert_node_to_ast(:text, text, _),
    do: {:ok, %AST.Literal{value: text}}

  defp convert_node_to_ast(:interpolation, {_, text, node_meta}, compile_meta) do
    meta = Helpers.to_meta(node_meta, compile_meta)

    expr = Helpers.interpolation_to_quoted!(text, meta)

    Helpers.perform_assigns_checks(expr, compile_meta)

    {:ok,
     %AST.Interpolation{
       original: text,
       value: expr,
       meta: meta
     }}
  end

  defp convert_node_to_ast(:template, {_, attributes, children, node_meta}, compile_meta) do
    meta = Helpers.to_meta(node_meta, compile_meta)

    with {:ok, directives, attributes} <-
           collect_directives(@template_directive_handlers, attributes, meta),
         slot <- attribute_value(attributes, "slot", :default) do
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
      meta.caller.module
      |> Surface.API.get_slots()

    # TODO: Validate attributes with custom messages
    name = attribute_value(attributes, "name", :default)
    short_slot_syntax? = not has_attribute?(attributes, "name")

    index =
      attribute_value_as_ast(attributes, "index", %Surface.AST.Literal{value: 0}, compile_meta)

    with {:ok, directives, _attrs} <-
           collect_directives(@slot_directive_handlers, attributes, meta),
         slot <- Enum.find(defined_slots, fn slot -> slot.name == name end),
         slot when not is_nil(slot) <- slot do
      maybe_warn_required_slot_with_default_value(slot, children, short_slot_syntax?, meta)

      {:ok,
       %AST.Slot{
         name: name,
         index: index,
         directives: directives,
         default: to_ast(children, compile_meta),
         props: [],
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
         attributes <- process_attributes(nil, attributes, meta),
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
      {:error, message} ->
        message = "cannot render <#{name}> (#{message})"
        {:error, message}

      _ ->
        {:error, {"cannot render <#{name}>", meta.line}, meta}
    end
  end

  defp convert_node_to_ast(:void_tag, {name, attributes, children, node_meta}, compile_meta) do
    meta = Helpers.to_meta(node_meta, compile_meta)

    with {:ok, directives, attributes} <-
           collect_directives(@tag_directive_handlers, attributes, meta),
         attributes <- process_attributes(nil, attributes, meta),
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
      {:error, message} ->
        message = "cannot render <#{name}> (#{message})"
        {:error, message}

      _ ->
        {:error, {"cannot render <#{name}>", meta.line}, meta}
    end
  end

  defp convert_node_to_ast(:component, {name, attributes, children, node_meta}, compile_meta) do
    # TODO: validate live views vs live components ?
    meta = Helpers.to_meta(node_meta, compile_meta)
    mod = Helpers.actual_component_module!(name, meta.caller)
    meta = Map.merge(meta, %{module: mod, node_alias: name})

    with :ok <- Helpers.validate_component_module(mod, name),
         true <- function_exported?(mod, :component_type, 0),
         component_type <- mod.component_type(),
         # This is a little bit hacky. :let will only be extracted for the default
         # template if `mod` doesn't export __slot_name__ (i.e. if it isn't a slotable component)
         # we pass in and modify the attributes so that non-slotable components are not
         # processed by the :let directive
         {:ok, templates, attributes} <-
           collect_templates(mod, attributes, children, meta),
         :ok <- validate_templates(mod, templates, meta),
         {:ok, directives, attributes} <-
           collect_directives(@component_directive_handlers, attributes, meta),
         attributes <- process_attributes(mod, attributes, meta),
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
      {:error, message, details} ->
        {:error, {"cannot render <#{name}> (#{message})", details, meta.line}, meta}

      {:error, message} ->
        {:error, {"cannot render <#{name}> (#{message})", meta.line}, meta}

      _ ->
        {:error, {"cannot render <#{name}>", meta.line}, meta}
    end
  end

  defp convert_node_to_ast(
         :macro_component,
         {"#" <> name, attributes, children, node_meta},
         compile_meta
       ) do
    meta = Helpers.to_meta(node_meta, compile_meta)
    mod = Helpers.actual_component_module!(name, meta.caller)
    meta = Map.merge(meta, %{module: mod, node_alias: name})

    with :ok <- Helpers.validate_component_module(mod, name),
         meta <- Map.merge(meta, %{module: mod, node_alias: name}),
         true <- function_exported?(mod, :expand, 3),
         {:ok, directives, attributes} <-
           collect_directives(@meta_component_directive_handlers, attributes, meta),
         attributes <- process_attributes(mod, attributes, meta),
         :ok <- validate_properties(mod, attributes, directives, meta) do
      expanded = mod.expand(attributes, children, meta)

      {:ok,
       %AST.Container{
         children: List.wrap(expanded),
         directives: directives,
         meta: meta
       }}
    else
      false ->
        {:error,
         {"cannot render <#{name}> (MacroComponents must export an expand/3 function)",
          meta.line}, meta}

      {:error, message, details} ->
        {:error, {"cannot render <#{name}> (#{message})", details, meta.line}, meta}

      {:error, message} ->
        {:error, {"cannot render <#{name}> (#{message})", meta.line}, meta}

      _ ->
        {:error, {"cannot render <#{name}>", meta.line}, meta}
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

  defp attribute_value_as_ast(attributes, attr_name, default, meta) do
    Enum.find_value(attributes, default, fn
      {^attr_name, {:attribute_expr, value, expr_meta}, _attr_meta} ->
        expr_meta = Helpers.to_meta(expr_meta, meta)

        %AST.AttributeExpr{
          original: value,
          value: Surface.TypeHandler.expr_to_quoted!(value, attr_name, :integer, expr_meta),
          meta: expr_meta
        }

      {^attr_name, value, attr_meta} ->
        attr_meta = Helpers.to_meta(attr_meta, meta)
        Surface.TypeHandler.literal_to_ast_node!(:integer, attr_name, value, attr_meta)

      _ ->
        nil
    end)
  end

  defp component_slotable?(mod), do: function_exported?(mod, :__slot_name__, 0)

  defp process_attributes(_module, [], _meta), do: []

  defp process_attributes(mod, [{name, value, attr_meta} | attrs], meta) do
    name = String.to_atom(name)
    attr_meta = Helpers.to_meta(attr_meta, meta)
    {type, type_opts} = Surface.TypeHandler.attribute_type_and_opts(mod, name, attr_meta)

    node = %AST.Attribute{
      type: type,
      type_opts: type_opts,
      name: name,
      value: attr_value(name, type, value, attr_meta),
      meta: attr_meta
    }

    [node | process_attributes(mod, attrs, meta)]
  end

  defp attr_value(name, type, values, attr_meta) when is_list(values) do
    {originals, quoted_values} =
      Enum.reduce(values, {[], []}, fn
        {:attribute_expr, value, expr_meta}, {originals, quoted_values} ->
          expr_meta = Helpers.to_meta(expr_meta, attr_meta)
          {["{{#{value}}}" | originals], [quote_embedded_expr(value, expr_meta) | quoted_values]}

        value, {originals, quoted_values} ->
          {[value | originals], [value | quoted_values]}
      end)

    original = originals |> Enum.reverse() |> Enum.join()
    quoted_values = Enum.reverse(quoted_values)
    expr_value = {:<<>>, [line: attr_meta.line], quoted_values}

    %AST.AttributeExpr{
      original: original,
      value: Surface.TypeHandler.expr_to_quoted!(expr_value, name, type, attr_meta, original),
      meta: attr_meta
    }
  end

  defp attr_value(name, type, {:attribute_expr, value, expr_meta}, attr_meta) do
    expr_meta = Helpers.to_meta(expr_meta, attr_meta)

    %AST.AttributeExpr{
      original: value,
      value: Surface.TypeHandler.expr_to_quoted!(value, name, type, expr_meta),
      meta: expr_meta
    }
  end

  defp attr_value(name, type, value, meta) do
    Surface.TypeHandler.literal_to_ast_node!(type, name, value, meta)
  end

  defp quote_embedded_expr(value, expr_meta) do
    meta = [line: expr_meta.line]
    quoted_value = Code.string_to_quoted!(value, meta)

    {:"::", meta,
     [
       {{:., meta, [Kernel, :to_string]}, meta, [quoted_value]},
       {:binary, meta, Elixir}
     ]}
  end

  defp validate_tag_children([]), do: :ok

  defp validate_tag_children([%AST.Template{name: name} | _]) do
    {:error,
     "templates are only allowed as children elements of components, but found template for #{
       name
     }"}
  end

  defp validate_tag_children([_ | nodes]), do: validate_tag_children(nodes)

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

  defp collect_directives(handlers, attributes, meta)
  defp collect_directives(_, [], _), do: {:ok, [], []}

  defp collect_directives(handlers, [attr | attributes], meta) do
    {:ok, dirs, attrs} = collect_directives(handlers, attributes, meta)

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
        IOHelper.warn(message, meta.caller, fn _ -> meta.line end)
      end
    end

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
      IOHelper.warn(message, meta.caller, fn _ -> meta.line end)
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
      props = Keyword.keys(template.let)

      prop_meta =
        Enum.find_value(template.directives, meta, fn directive ->
          if directive.module == Surface.Directive.Let do
            directive.meta
          end
        end)

      case slot do
        %{opts: opts} ->
          non_generator_args = Enum.map(opts[:props] || [], &Map.get(&1, :name))

          undefined_keys = props -- non_generator_args

          if not Enum.empty?(undefined_keys) do
            [prop | _] = undefined_keys

            message = """
            undefined prop `#{inspect(prop)}` for slot `#{slot_name}` in `#{inspect(mod)}`.

            Available props: #{inspect(non_generator_args)}.

            Hint: You can define a new slot prop using the `props` option: \
            `slot #{slot_name}, props: [..., #{inspect(prop)}]`\
            """

            IOHelper.compile_error(message, prop_meta.file, prop_meta.line)
          end

        _ ->
          :ok
      end
    end

    :ok
  end

  defp raise_missing_slot_error!(
         module,
         slot_name,
         meta,
         _defined_slots,
         true = _short_syntax?
       ) do
    message = """
    no slot `#{slot_name}` defined in the component `#{inspect(module)}`

    Please declare the default slot using `slot default` in order to use the `<slot />` notation.
    """

    IOHelper.compile_error(message, meta.file, meta.line)
  end

  defp raise_missing_slot_error!(
         module,
         slot_name,
         meta,
         defined_slots,
         false = _short_syntax?
       ) do
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
        <slot#{slot_name_tag}>Fallback content</slot>

      or keep the slot as required and remove the fallback content:

        slot #{slot.name}, required: true`
        ...
        <slot#{slot_name_tag} />

      but not both.
      """

      IOHelper.warn(message, meta.caller, fn _ -> meta.line end)
    end
  end
end
