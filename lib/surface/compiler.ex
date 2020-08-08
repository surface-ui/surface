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
    Surface.Directive.Events,
    Surface.Directive.Show,
    Surface.Directive.If,
    Surface.Directive.For,
    Surface.Directive.Debug
  ]

  @component_directive_handlers [
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

  @boolean_tag_attributes [
    :allowfullscreen,
    :allowpaymentrequest,
    :async,
    :autofocus,
    :autoplay,
    :checked,
    :controls,
    :default,
    :defer,
    :disabled,
    :formnovalidate,
    :hidden,
    :ismap,
    :itemscope,
    :loop,
    :multiple,
    :muted,
    :nomodule,
    :novalidate,
    :open,
    :readonly,
    :required,
    :reversed,
    :selected,
    :typemustmatch
  ]

  @void_elements [
    "area",
    "base",
    "br",
    "col",
    "hr",
    "img",
    "input",
    "link",
    "meta",
    "param",
    "command",
    "keygen",
    "source"
  ]

  defmodule ParseError do
    defexception file: "", line: 0, message: "error parsing HTML/Surface"

    @impl true
    def message(exception) do
      "#{Path.relative_to_cwd(exception.file)}:#{exception.line}: #{exception.message}"
    end
  end

  defmodule CompileMeta do
    defstruct [:line_offset, :file, :caller]

    @type t :: %__MODULE__{
            line_offset: non_neg_integer(),
            file: binary(),
            caller: Macro.Env.t()
          }
  end

  @doc """
  This function compiles a string into the Surface AST.This is used by ~H and Surface.Renderer to parse and compile templates.

  A special note for line_offset: This is considered the line number for the first line in the string. If the first line of the
  string is also the first line of the file, then this should be 1. If this is being called within a macro (say to process a heredoc
  passed to ~H), this should be __CALLER__.line + 1.
  """
  @spec compile(binary, non_neg_integer(), Macro.Env.t(), binary()) :: [Surface.AST.t()]
  def compile(string, line_offset, caller, file \\ "nofile") do
    compile_meta = %CompileMeta{
      line_offset: line_offset,
      file: file,
      caller: caller
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

  defp validate_stateful_component(ast, %CompileMeta{line_offset: offset, caller: caller}) do
    num_tags =
      ast
      |> Enum.filter(fn
        %AST.Tag{} -> true
        %AST.VoidTag{} -> true
        %AST.Component{} -> true
        _ -> false
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

  defp to_ast(nodes, compile_meta) do
    for node <- nodes do
      case convert_node_to_ast(node_type(node), node, compile_meta) do
        {:ok, ast} ->
          process_directives(ast)

        {:error, {message, line}, meta} ->
          IOHelper.warn(message, compile_meta.caller, fn _ -> line end)
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
    do: {:ok, %AST.Text{value: text}}

  defp convert_node_to_ast(:interpolation, {_, text, node_meta}, compile_meta) do
    meta = Helpers.to_meta(node_meta, compile_meta)

    {:ok,
     %AST.Interpolation{
       original: text,
       value: Helpers.interpolation_to_quoted!(text, meta),
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
         let: template_props(directives, meta),
         meta: meta
       }}
    else
      _ -> {:error, {"failed to parse template", meta.line}, meta}
    end
  end

  defp convert_node_to_ast(:slot, {_, attributes, children, node_meta}, compile_meta) do
    meta = Helpers.to_meta(node_meta, compile_meta)

    with name when not is_nil(name) and is_atom(name) <-
           attribute_value(attributes, "name", :default),
         {:ok, props, _attributes} <-
           collect_directives([Surface.Directive.SlotProps], attributes, meta) do
      props =
        case props do
          [expr] ->
            expr

          _ ->
            %AST.Directive{
              module: Surface.Directive.SlotProps,
              name: :props,
              value: %AST.AttributeExpr{
                original: "",
                value: [],
                meta: meta
              },
              meta: meta
            }
        end

      Module.put_attribute(meta.caller.module, :used_slot, %{name: name, line: meta.line})

      {:ok,
       %AST.Slot{
         name: name,
         default: to_ast(children, compile_meta),
         props: props,
         meta: meta
       }}
    else
      _ -> {:error, {"failed to parse slot", meta.line}, meta}
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

    with {:ok, mod} <- Helpers.module_name(name, meta.caller),
         true <- function_exported?(mod, :component_type, 0),
         component_type <- mod.component_type(),
         meta <- Map.merge(meta, %{module: mod, node_alias: name}),
         # Passing in and modifying attributes here because :let on the parent is used
         # to indicate the props for the :default slot's template
         {:ok, templates, attributes} <-
           collect_templates(mod, attributes, children, meta),
         :ok <- validate_templates(mod, templates, meta),
         # This is a little bit hacky. :let will only be extracted for the default
         # template if `mod` doesn't export __slot_name__ (i.e. if it isn't a slotable component)
         # We have to extract that here as it should not be considered an attribute
         {:ok, template_directives, attributes} <-
           maybe_collect_template_directives(mod, attributes, meta),
         {:ok, directives, attributes} <-
           collect_directives(@component_directive_handlers, attributes, meta),
         attributes <- process_attributes(mod, attributes, meta),
         :ok <- validate_properties(mod, attributes, meta) do
      result =
        if component_slotable?(mod) do
          %AST.SlotableComponent{
            module: mod,
            slot: mod.__slot_name__(),
            type: component_type,
            let: template_props(template_directives, meta),
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

      {:ok, result}
    else
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

    with {:ok, mod} <- Helpers.module_name(name, meta.caller),
         meta <- Map.merge(meta, %{module: mod, node_alias: name}),
         true <- function_exported?(mod, :expand, 3),
         {:ok, directives, attributes} <-
           collect_directives(@meta_component_directive_handlers, attributes, meta),
         attributes <- process_attributes(mod, attributes, meta),
         :ok <- validate_properties(mod, attributes, meta) do
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

      {:error, message} ->
        {:error, {"cannot render <#{name}> (#{message})", meta.line}, meta}

      _ ->
        {:error, {"cannot render <#{name}>", meta.line}, meta}
    end
  end

  defp attribute_value(attributes, attr_name, default) do
    Enum.find_value(attributes, default, fn {name, value, _} ->
      if name == attr_name do
        List.to_atom(value)
      end
    end)
  end

  defp coerce_to_list(list) when is_list(list), do: list
  defp coerce_to_list(not_list), do: [not_list]

  defp template_props([], meta),
    do: %AST.Directive{
      module: Surface.Directive.Let,
      name: :let,
      value: %AST.AttributeExpr{
        value: [],
        original: "",
        meta: meta
      },
      meta: meta
    }

  defp template_props([%AST.Directive{module: Surface.Directive.Let} = props | _], _meta),
    do: props

  defp template_props([_ | directives], meta), do: template_props(directives, meta)

  defp component_slotable?(mod), do: function_exported?(mod, :__slot_name__, 0)

  defp maybe_collect_template_directives(mod, attributes, meta) do
    if component_slotable?(mod) do
      collect_directives(@template_directive_handlers, attributes, meta)
    else
      {:ok, [], attributes}
    end
  end

  defp process_attributes(_module, [], _meta), do: []

  defp process_attributes(
         mod,
         [{name, {:attribute_expr, [value], expr_meta}, attr_meta} | attrs],
         meta
       ) do
    name = String.to_atom(name)
    expr_meta = Helpers.to_meta(expr_meta, meta)
    attr_meta = Helpers.to_meta(attr_meta, meta)
    type = determine_attribute_type(mod, name, attr_meta)

    [
      %AST.Attribute{
        type: type,
        name: name,
        value: [expr_node(name, value, expr_meta, type)],
        meta: attr_meta
      }
      | process_attributes(mod, attrs, meta)
    ]
  end

  defp process_attributes(mod, [{name, [], attr_meta} | attrs], meta) do
    name = String.to_atom(name)
    attr_meta = Helpers.to_meta(attr_meta, meta)
    type = determine_attribute_type(mod, name, attr_meta)

    attr_value =
      case type do
        type when type in [:string, :css_class, :any] ->
          %AST.Text{
            value: ""
          }

        :event ->
          %AST.AttributeExpr{
            original: "",
            value: nil,
            meta: attr_meta
          }

        :boolean ->
          %AST.Text{value: true}

        type ->
          message =
            "invalid property value for #{name}, expected #{type}, but got an empty string"

          IOHelper.compile_error(message, meta.file, meta.line)
      end

    [
      %AST.Attribute{
        type: type,
        name: name,
        value: [attr_value],
        meta: attr_meta
      }
      | process_attributes(mod, attrs, meta)
    ]
  end

  defp process_attributes(mod, [{name, value, attr_meta} | attrs], meta)
       when is_bitstring(value) or is_binary(value) do
    name = String.to_atom(name)
    attr_meta = Helpers.to_meta(attr_meta, meta)
    type = determine_attribute_type(mod, name, attr_meta)

    [
      %AST.Attribute{
        type: type,
        name: name,
        value: [attr_value(name, type, value, meta)],
        meta: attr_meta
      }
      | process_attributes(mod, attrs, meta)
    ]
  end

  defp process_attributes(mod, [{name, values, attr_meta} | attrs], meta)
       when is_list(values) do
    name = String.to_atom(name)
    attr_meta = Helpers.to_meta(attr_meta, meta)
    type = determine_attribute_type(mod, name, attr_meta)
    values = collect_attr_values(name, meta, values, type)

    [
      %AST.Attribute{
        type: type,
        name: name,
        value: values,
        meta: attr_meta
      }
      | process_attributes(mod, attrs, meta)
    ]
  end

  defp process_attributes(mod, [{name, value, attr_meta} | attrs], meta)
       when is_boolean(value) do
    name = String.to_atom(name)
    attr_meta = Helpers.to_meta(attr_meta, meta)
    type = determine_attribute_type(mod, name, attr_meta)

    [
      %AST.Attribute{
        type: type,
        name: name,
        value: [attr_value(name, type, value, meta)],
        meta: attr_meta
      }
      | process_attributes(mod, attrs, meta)
    ]
  end

  defp determine_attribute_type(nil, :class, _meta), do: :css_class

  defp determine_attribute_type(nil, name, _meta) when name in @boolean_tag_attributes,
    do: :boolean

  defp determine_attribute_type(nil, _name, _meta), do: :string

  defp determine_attribute_type(module, name, meta) do
    with true <- function_exported?(module, :__get_prop__, 1),
         prop when not is_nil(prop) <- module.__get_prop__(name) do
      prop.type
    else
      _ ->
        IOHelper.warn(
          "Unknown property \"#{to_string(name)}\" for component <#{meta.node_alias}>",
          meta.caller,
          fn _ ->
            meta.line
          end
        )

        :string
    end
  end

  defp collect_attr_values(attribute_name, meta, values, type, accumulators \\ {[], []})

  defp collect_attr_values(_attribute_name, _meta, [], _type, {[], acc}), do: Enum.reverse(acc)

  defp collect_attr_values(attribute_name, meta, [], type, {codepoints, acc}) do
    collect_attr_values(
      attribute_name,
      meta,
      [],
      type,
      {[],
       [
         attr_value(attribute_name, type, codepoints |> Enum.reverse() |> List.to_string(), meta)
         | acc
       ]}
    )
  end

  defp collect_attr_values(
         attribute_name,
         meta,
         [{:attribute_expr, [value], expr_meta} | values],
         type,
         {[], acc}
       ) do
    collect_attr_values(
      attribute_name,
      meta,
      values,
      type,
      {[], [expr_node(attribute_name, value, Helpers.to_meta(expr_meta, meta), type) | acc]}
    )
  end

  defp collect_attr_values(
         attribute_name,
         meta,
         [{:attribute_expr, [value], expr_meta} | values],
         type,
         {codepoints, acc}
       ) do
    text_node =
      attr_value(attribute_name, type, codepoints |> Enum.reverse() |> List.to_string(), meta)

    acc = [text_node | acc]

    collect_attr_values(
      attribute_name,
      meta,
      values,
      type,
      {[], [expr_node(attribute_name, value, Helpers.to_meta(expr_meta, meta), type) | acc]}
    )
  end

  defp collect_attr_values(attribute_name, meta, [codepoint | values], type, {codepoint_acc, acc}) do
    collect_attr_values(attribute_name, meta, values, type, {[codepoint | codepoint_acc], acc})
  end

  defp attr_value(name, :event, value, meta) do
    %AST.AttributeExpr{
      original: value,
      value: Helpers.attribute_expr_to_quoted!(Macro.to_string(value), name, :event, meta),
      meta: meta
    }
  end

  defp attr_value(_name, _type, value, _meta) do
    %AST.Text{value: value}
  end

  defp expr_node(attribute_name, value, meta, type) do
    # This is required as nimble_parsec appears to generate bitstrings that elixir doesn't
    # want to interpret as actual strings.
    # The exact example is " \"héllo\" " which generates <<32, 34, 104, 233, 108, 108, 111, 34, 32>>.
    # When that sequence is passed to Code.string_to_quoted(), it results in:
    # ** (UnicodeConversionError) invalid encoding starting at <<233, 108, 108, 111, 34, 32>>
    # (elixir 1.10.4) lib/string.ex:2251: String.to_charlist/1
    # (elixir 1.10.4) lib/code.ex:834: Code.string_to_quoted/2
    binary = List.to_string(for <<c <- value>>, into: [], do: c)

    %AST.AttributeExpr{
      original: binary,
      value: Helpers.attribute_expr_to_quoted!(binary, attribute_name, type, meta),
      meta: meta
    }
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
    {:ok, default_props, attributes} =
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
      wrapped = %AST.Template{
        name: :default,
        children: default_children,
        let: template_props(default_props, meta),
        meta: meta
      }

      {:ok, Map.put(templates, :default, [wrapped | already_wrapped]), attributes}
    end
  end

  defp collect_directives(handlers, attributes, meta)
  defp collect_directives(_, [], _), do: {:ok, [], []}

  defp collect_directives(handlers, [attr | attributes], meta) do
    {:ok, dirs, attrs} = collect_directives(handlers, attributes, meta)

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

  defp validate_properties(module, props, meta) do
    if function_exported?(module, :__props__, 0) do
      existing_props = Enum.map(props, fn %{name: name} -> name end)

      required_props =
        for p <- module.__props__(), Keyword.get(p.opts, :required, false), do: p.name

      missing_props = required_props -- existing_props

      for prop <- missing_props do
        message = "Missing required property \"#{prop}\" for component <#{meta.node_alias}>"
        IOHelper.warn(message, meta.caller, fn _ -> meta.line end)
      end
    end

    :ok
  end

  defp validate_templates(mod, templates, meta) do
    names =
      templates
      |> Map.keys()
      |> Enum.reject(fn name -> name == :default end)

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

    for slot_name <- names,
        mod.__get_slot__(slot_name) == nil do
      missing_slot(mod, slot_name, meta)
    end

    for slot_name <- Map.keys(templates),
        template <- Map.get(templates, slot_name) do
      slot = mod.__get_slot__(slot_name)

      {props, prop_meta} =
        case template.let do
          %AST.Directive{
            value: %AST.AttributeExpr{
              value: value,
              meta: meta
            }
          } ->
            {Keyword.keys(value), meta}

          _ ->
            {[], meta}
        end

      if slot == nil and not Enum.empty?(props) do
        message = """
        there's no `#{slot_name}` slot defined in `#{inspect(mod)}`.

        Directive :let can only be used on explicitly defined slots.

        Hint: You can define a `#{slot_name}` slot and its props using: \
        `slot #{slot_name}, props: #{inspect(props)}\
        """

        IOHelper.compile_error(message, meta.file, meta.line)
      end

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

  defp missing_slot(mod, slot_name, meta) do
    parent_slots = mod.__slots__() |> Enum.map(& &1.name)

    similar_slot_message =
      case Helpers.did_you_mean(slot_name, parent_slots) do
        {similar, score} when score > 0.8 ->
          "\n\n  Did you mean #{inspect(to_string(similar))}?"

        _ ->
          ""
      end

    existing_slots_message =
      if parent_slots == [] do
        ""
      else
        slots = Enum.map(parent_slots, &to_string/1)
        available = Helpers.list_to_string("slot:", "slots:", slots)
        "\n\n  Available #{available}"
      end

    message = """
    no slot "#{slot_name}" defined in parent component <#{meta.node_alias}>\
    #{similar_slot_message}\
    #{existing_slots_message}\
    """

    IOHelper.warn(message, meta.caller, fn _ -> meta.line + 1 end)
  end
end
