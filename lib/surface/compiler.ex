defmodule Surface.Compiler do
  @moduledoc """
  Defines a behaviour that must be implemented by all HTML/Surface node translators.

  This module also contains the main logic to translate Surface code.
  """

  alias Surface.Translator.Parser
  alias Surface.IOHelper
  alias Surface.AST
  alias Surface.Compiler.Helpers

  @tag_directive_handlers [
    Surface.Directive.For,
    Surface.Directive.If,
    Surface.Directive.Show,
    Surface.Directive.Debug,
    Surface.Directive.Events
  ]

  @component_directive_handlers [
    Surface.Directive.For,
    Surface.Directive.If,
    Surface.Directive.Debug,
    Surface.Directive.Events
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

  @spec compile(
          binary,
          any,
          atom | %{:__struct__ => atom, :module => atom, optional(atom) => any},
          any
        ) :: [any]
  def compile(string, line_offset, caller, file \\ "nofile") do
    compile_meta = %CompileMeta{
      line_offset: line_offset,
      file: file,
      caller: caller
    }

    ast =
      string
      |> Parser.parse()
      |> case do
        {:ok, nodes} ->
          nodes

        {:error, message, line} ->
          raise %ParseError{line: line + line_offset - 1, file: file, message: message}
      end
      |> process_nodes(compile_meta)

    if is_stateful_component(caller.module) do
      validate_stateful_component(ast, compile_meta)
    else
      ast
    end
  end

  def to_live_struct(_nodes) do
    # TODO: this still needs work
    rendered =
      quote do
        %Phoenix.LiveView.Rendered{
          static: ["<span>this is not yet implemented</span>"],
          dynamic: fn _ -> [] end,
          fingerprint: 1
        }
      end

    quote do
      require Phoenix.LiveView.Engine
      unquote(rendered)
    end
  end

  defp is_stateful_component(module) do
    if Module.open?(module) do
      Module.get_attribute(module, :__is_stateful__, false)
    else
      function_exported?(module, :__is_stateful__, 0) and module.__is_stateful__()
    end
  end

  defp validate_stateful_component(ast, %CompileMeta{line_offset: offset, caller: caller}) do
    num_tags =
      ast
      |> Enum.filter(fn
        %AST.Tag{} -> true
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

    ast
  end

  defp process_nodes([], _compile_meta) do
    []
  end

  defp process_nodes([{"#" <> name, attributes, children, node_meta} | nodes], compile_meta) do
    meta = Helpers.to_meta(node_meta, compile_meta)

    # Some of this should likely be removed as macro components should
    # be minimally processed
    with {:ok, mod} <- module_name(name, meta.caller),
         meta <- Map.merge(meta, %{module: mod, node_alias: name}),
         true <- function_exported?(mod, :expand, 5),
         # Passing in and modifying attributes here because :let on the parent is used
         # to indicate the props for the :default slot's template
         # Is this something we actually want to do for macro components?
         {:ok, templates, attributes} <-
           collect_templates(mod, attributes, children, meta),
         :ok <- validate_templates(mod, templates, meta),
         {:ok, directives, attributes} <-
           collect_directives(@component_directive_handlers, attributes, meta),
         attributes <- process_attributes(mod, attributes, meta),
         :ok <- validate_properties(mod, attributes, meta),
         siblings <- process_nodes(nodes, compile_meta) do
      # Unsure if this is the appropriate place to expand macros
      # but it feels reasonable
      case mod.expand(directives, attributes, templates, children, meta) do
        result when is_list(result) -> result ++ siblings
        result -> [result | siblings]
      end
    else
      false ->
        message = "cannot render <#{name}> (MacroComponents must export an expand/6 function)"
        IOHelper.warn(message, meta.caller, fn _ -> meta.line - 1 end)

        [
          %AST.Error{message: message, meta: meta}
          | process_nodes(nodes, compile_meta)
        ]

      {:error, message} ->
        message = "cannot render <#{name}> (#{message})"
        IOHelper.warn(message, meta.caller, fn _ -> meta.line - 1 end)

        [
          %AST.Error{message: message, meta: meta}
          | process_nodes(nodes, compile_meta)
        ]
    end
  end

  defp process_nodes(
         [{<<first, _::binary>> = name, attributes, children, node_meta} | nodes],
         compile_meta
       )
       when first in ?A..?Z do
    meta = Helpers.to_meta(node_meta, compile_meta)

    with {:ok, mod} <- module_name(name, meta.caller),
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
      [
        maybe_slotable_component(
          mod,
          attributes,
          template_directives,
          directives,
          templates,
          meta
        )
        | process_nodes(nodes, compile_meta)
      ]
    else
      {:error, message} ->
        message = "cannot render <#{name}> (#{message})"
        IOHelper.warn(message, meta.caller, fn _ -> meta.line end)

        [
          %AST.Error{message: message, meta: meta}
          | process_nodes(nodes, compile_meta)
        ]
    end
  end

  defp process_nodes([{"template", attributes, children, node_meta} | nodes], compile_meta) do
    meta = Helpers.to_meta(node_meta, compile_meta)

    {:ok, props, attributes} = collect_directives(@template_directive_handlers, attributes, meta)

    name =
      case find_attribute_and_line(attributes, "slot") do
        {slot, _} -> slot
        _ -> :default
      end

    [
      %AST.Template{
        name: name,
        children: process_nodes(children, compile_meta),
        props: if(Enum.empty?(props), do: :no_props, else: Enum.at(props, 0)),
        meta: meta
      }
      | process_nodes(nodes, compile_meta)
    ]
  end

  defp process_nodes([{"slot", attributes, children, node_meta} | nodes], compile_meta) do
    meta = Helpers.to_meta(node_meta, compile_meta)

    slot =
      attributes
      |> Enum.reduce(
        {nil, "[]"},
        fn
          {"name", value, _meta}, {_, props_expr} ->
            {List.to_atom(value), props_expr}

          {":props", {:attribute_expr, [expr], _}, _meta}, {name, _} ->
            {name, expr}

          _, acc ->
            acc
        end
      )
      |> case do
        {name, props_expr} when is_binary(props_expr) ->
          %AST.Slot{
            name: name,
            default: process_nodes(children, compile_meta),
            props: props_expr,
            meta: meta
          }

        {name, _} ->
          %AST.Error{
            message: "could not parse slot #{name}",
            meta: meta
          }
      end

    [slot | process_nodes(nodes, compile_meta)]
  end

  defp process_nodes([{tag_name, attributes, children, node_meta} | nodes], compile_meta) do
    meta = Helpers.to_meta(node_meta, compile_meta)

    with {:ok, directives, attributes} <-
           collect_directives(@tag_directive_handlers, attributes, meta),
         attributes <- process_attributes(nil, attributes, meta),
         children <- process_nodes(children, compile_meta),
         :ok <- validate_tag_children(children) do
      [
        %AST.Tag{
          element: tag_name,
          attributes: attributes,
          directives: directives,
          children: children,
          meta: meta
        }
        | process_nodes(nodes, compile_meta)
      ]
    else
      {:error, message} ->
        message = "cannot render <#{tag_name}> (#{message})"
        IOHelper.warn(message, meta.caller, fn _ -> meta.line end)

        [
          %AST.Error{message: message, meta: meta}
          | process_nodes(nodes, compile_meta)
        ]
    end
  end

  defp process_nodes([{:interpolation, text, node_meta} | nodes], compile_meta) do
    meta = Helpers.to_meta(node_meta, compile_meta)

    expr = Helpers.interpolation_to_quoted!(text, meta)

    [
      %AST.Interpolation{value: expr, meta: meta}
      | process_nodes(nodes, compile_meta)
    ]
  end

  defp process_nodes([text | nodes], compile_meta) do
    [%AST.Text{value: text} | process_nodes(nodes, compile_meta)]
  end

  defp maybe_collect_template_directives(mod, attributes, meta) do
    if function_exported?(mod, :__slot_name__, 0) do
      collect_directives(@template_directive_handlers, attributes, meta)
    else
      {:ok, [], attributes}
    end
  end

  defp maybe_slotable_component(
         mod,
         attributes,
         template_directives,
         directives,
         templates,
         meta
       ) do
    component = %AST.Component{
      module: mod,
      props: attributes,
      directives: directives,
      templates: templates,
      meta: meta
    }

    if function_exported?(mod, :__slot_name__, 0) do
      %AST.Template{
        name: mod.__slot_name__(),
        props:
          if(Enum.empty?(template_directives),
            do: :no_props,
            else: Enum.at(template_directives, 0)
          ),
        children: [component],
        meta: meta
      }
    else
      component
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
        value: [expr_node(value, expr_meta, type)],
        meta: attr_meta
      }
      | process_attributes(mod, attrs, meta)
    ]
  end

  defp process_attributes(mod, [{name, value, attr_meta} | attrs], meta)
       when is_bitstring(value) or is_binary(value) do
    name = String.to_atom(name)
    attr_meta = Helpers.to_meta(attr_meta, meta)

    [
      %AST.Attribute{
        type: determine_attribute_type(mod, name, attr_meta),
        name: name,
        value: [%AST.Text{value: value}],
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
    values = collect_attr_values(meta, values, type)

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

    [
      %AST.Attribute{
        type: determine_attribute_type(mod, name, attr_meta),
        name: name,
        value: [%AST.Text{value: value}],
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

  defp collect_attr_values(meta, values, type, accumulators \\ {[], []})

  defp collect_attr_values(_meta, [], _type, {[], acc}), do: Enum.reverse(acc)

  defp collect_attr_values(meta, [], type, {codepoints, acc}) do
    collect_attr_values(
      meta,
      [],
      type,
      {[], [%AST.Text{value: codepoints |> Enum.reverse() |> List.to_string()} | acc]}
    )
  end

  defp collect_attr_values(
         meta,
         [{:attribute_expr, [value], expr_meta} | values],
         type,
         {[], acc}
       ) do
    collect_attr_values(
      meta,
      values,
      type,
      {[], [expr_node(value, Helpers.to_meta(expr_meta, meta), type) | acc]}
    )
  end

  defp collect_attr_values(
         meta,
         [{:attribute_expr, [value], expr_meta} | values],
         type,
         {codepoints, acc}
       ) do
    text_node = %AST.Text{
      value: codepoints |> Enum.reverse() |> List.to_string()
    }

    acc = [text_node | acc]

    collect_attr_values(
      meta,
      values,
      type,
      {[], [expr_node(value, Helpers.to_meta(expr_meta, meta), type) | acc]}
    )
  end

  defp collect_attr_values(meta, [codepoint | values], type, {codepoint_acc, acc}) do
    collect_attr_values(meta, values, type, {[codepoint | codepoint_acc], acc})
  end

  defp expr_node(value, meta, type) do
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
      value: Helpers.attribute_expr_to_quoted!(binary, type, meta),
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

  defp module_name(name, caller) do
    with {:ok, mod} <- actual_module(name, caller),
         {:ok, mod} <- check_module_loaded(mod, name) do
      check_module_is_component(mod, name)
    end
  end

  defp collect_templates(mod, attributes, nodes, meta) do
    # Don't extract the template directives if this module is slotable
    {:ok, default_props, attributes} =
      if function_exported?(mod, :__slot_name__, 0) do
        {:ok, [], attributes}
      else
        collect_directives(@template_directive_handlers, attributes, meta)
      end

    templates =
      nodes
      |> process_nodes(meta)
      |> Enum.group_by(fn
        %AST.Template{name: name} -> name
        _ -> :default
      end)

    {already_wrapped, default_children} =
      templates
      |> Map.get(:default, [])
      |> Enum.split_with(fn
        %AST.Template{} -> true
        _ -> false
      end)

    if Enum.all?(default_children, &is_blank_or_empty/1) do
      {:ok, Map.put(templates, :default, already_wrapped), attributes}
    else
      wrapped = %AST.Template{
        name: :default,
        children: default_children,
        props: if(Enum.empty?(default_props), do: :no_props, else: Enum.at(default_props, 0)),
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

    if Enum.empty?(directives) do
      {:ok, dirs, [attr | attrs]}
    else
      {:ok, directives ++ dirs, attrs}
    end
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
          Enum.all?(Map.get(templates, name, []), &is_blank_or_empty/1) do
      message = "missing required slot \"#{name}\" for component <#{meta.node_alias}>"
      IOHelper.warn(message, meta.caller, fn _ -> meta.line - 1 end)
    end

    for slot_name <- names,
        mod.__get_slot__(slot_name) == nil do
      missing_slot(mod, slot_name, meta)
    end

    for slot_name <- Map.keys(templates),
        template <- Map.get(templates, slot_name) do
      slot = mod.__get_slot__(slot_name)
      # TODO validate slot props/lets
      {props, prop_meta} =
        case template.props do
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
      case did_you_mean(slot_name, parent_slots) do
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
        available = list_to_string("slot:", "slots:", slots)
        "\n\n  Available #{available}"
      end

    message = """
    no slot "#{slot_name}" defined in parent component <#{meta.node_alias}>\
    #{similar_slot_message}\
    #{existing_slots_message}\
    """

    IOHelper.warn(message, meta.caller, fn _ -> meta.line + 1 end)
  end

  defp did_you_mean(target, list) do
    Enum.reduce(list, {nil, 0}, &max_similar(&1, to_string(target), &2))
  end

  defp max_similar(source, target, {_, current} = best) do
    score = source |> to_string() |> String.jaro_distance(target)
    if score < current, do: best, else: {source, score}
  end

  defp list_to_string(_singular, _plural, []) do
    ""
  end

  defp list_to_string(singular, _plural, [item]) do
    "#{singular} #{inspect(item)}"
  end

  defp list_to_string(_singular, plural, items) do
    [last | rest] = items |> Enum.map(&inspect/1) |> Enum.reverse()
    "#{plural} #{rest |> Enum.reverse() |> Enum.join(", ")} and #{last}"
  end

  defp is_blank_or_empty(%AST.Text{value: value}),
    do: Surface.Translator.ComponentTranslatorHelper.blank?(value)

  defp is_blank_or_empty(%AST.Template{children: children}),
    do: Enum.all?(children, &is_blank_or_empty/1)

  defp is_blank_or_empty(_node), do: false

  defp actual_module(mod_str, env) do
    {:ok, ast} = Code.string_to_quoted(mod_str)

    case Macro.expand(ast, env) do
      mod when is_atom(mod) ->
        {:ok, mod}

      _ ->
        {:error, "#{mod_str} is not a valid module name"}
    end
  end

  defp check_module_loaded(module, mod_str) do
    case Code.ensure_compiled(module) do
      {:module, mod} ->
        {:ok, mod}

      {:error, _reason} ->
        {:error, "module #{mod_str} could not be loaded"}
    end
  end

  defp check_module_is_component(module, mod_str) do
    if function_exported?(module, :translator, 0) do
      {:ok, module}
    else
      {:error, "module #{mod_str} is not a component"}
    end
  end

  defp find_attribute_and_line(attributes, name) do
    Enum.find_value(attributes, fn {attr_name, value, %{line: line}} ->
      if name == attr_name do
        {List.to_atom(value), line}
      end
    end)
  end
end
