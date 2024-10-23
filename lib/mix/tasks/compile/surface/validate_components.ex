defmodule Mix.Tasks.Compile.Surface.ValidateComponents do
  alias Mix.Task.Compiler.Diagnostic
  alias Surface.Compiler.Helpers

  def validate(modules) do
    for module <- modules,
        Code.ensure_loaded?(module),
        function_exported?(module, :__components_calls__, 0) do
      check_components_calls(module)
    end
    |> List.flatten()
  end

  defp check_components_calls(module) do
    components_calls = module.__components_calls__()
    file = template_file(module)

    for component_call <- components_calls do
      validate_properties(file, component_call) ++
        validate_attributes(file, component_call) ++
        validate_directives(file, component_call)
    end
    |> Enum.reject(&is_nil/1)
  end

  # validates required properties with missing attributes

  defp validate_properties(file, component_call) do
    module = component_call.component
    props = component_call.props
    node_alias = component_call.node_alias
    line = component_call.line
    col = component_call.column
    directives = component_call.directives

    has_directive_props? = Enum.any?(directives, &match?(%{name: :props}, &1))

    if not has_directive_props? do
      existing_props_names = Enum.map(props, & &1.name)
      required_props_names = module.__required_props_names__()
      missing_props_names = required_props_names -- existing_props_names

      for prop_name <- missing_props_names do
        message = "missing required property \"#{prop_name}\" for component <#{node_alias}>"

        message =
          if prop_name == :id and Helpers.is_stateful_component(module) do
            message <>
              """
              \n\nHint: Components using `Surface.LiveComponent` automatically define a required `id` prop to make them stateful.
              If you meant to create a stateless component, you can switch to `use Surface.Component`.
              """
          else
            message
          end

        warning(message, file, {line, col})
      end
    else
      []
    end
  end

  # validates multiple attributes of properties without accumulate

  defp validate_attributes(file, component_call) do
    module = component_call.component

    {diagnostics, _} =
      for attr <- component_call.props,
          reduce: {[], MapSet.new()} do
        {diagnostics, attrs} ->
          prop = attr_prop(module, attr)

          cond do
            attr.root == true and is_nil(prop) ->
              message = """
              no root property defined for component <#{component_call.node_alias}>

              Hint: you can declare a root property using option `root: true`
              """

              diagnostics = [warning(message, file, {attr.line, attr.column}) | diagnostics]
              {diagnostics, attrs}

            true ->
              diagnostics = [validate_attribute(attr, prop, component_call.node_alias, file, attrs) | diagnostics]
              {diagnostics, MapSet.put(attrs, attr.name || prop.name)}
          end
      end

    diagnostics
    |> Enum.reject(&is_nil/1)
    |> Enum.reverse()
  end

  defp attr_prop(module, %{root: true}) do
    Enum.find(module.__props__(), & &1.opts[:root])
  end

  defp attr_prop(module, attr) do
    module.__get_prop__(attr.name)
  end

  defp validate_attribute(%{name: :__caller_scope_id__}, _prop, _node_alias, _file, _processed_attrs) do
    nil
  end

  defp validate_attribute(attr, nil, node_alias, file, _) do
    message = "Unknown property \"#{attr.name}\" for component <#{node_alias}>"
    warning(message, file, {attr.line, attr.column})
  end

  defp validate_attribute(attr, prop, node_alias, file, processed_attrs) do
    attr_processed? = MapSet.member?(processed_attrs, attr.name)

    if attr_processed? and !prop.opts[:accumulate] do
      attr_line = attr.line
      attr_col = attr.column

      message =
        if prop.opts[:root] == true do
          """
          the prop `#{attr.name}` has been passed multiple times. Considering only the last value.

          Hint: Either specify the `#{attr.name}` via the root property \(`<#{node_alias} { ... }>`\) or \
          explicitly via the #{attr.name} property \(`<#{node_alias} #{attr.name}="...">`\), but not both.
          """
        else
          """
          the prop `#{attr.name}` has been passed multiple times. Considering only the last value.

          Hint: Either remove all redundant definitions or set option `accumulate` to `true`:

          ```
            prop #{attr.name}, :string, accumulate: true
          ```

          This way the values will be accumulated in a list.
          """
        end

      warning(message, file, {attr_line, attr_col})
    end
  end

  defp validate_directives(file, component_call) do
    {diagnostics, _} =
      for directive <- component_call.directives,
          reduce: {[], MapSet.new()} do
        {diagnostics, directives} ->
          diagnostics = [validate_directive(directive, file, directives) | diagnostics]
          {diagnostics, MapSet.put(directives, directive.name)}
      end

    diagnostics
    |> Enum.reject(&is_nil/1)
    |> Enum.reverse()
  end

  defp validate_directive(directive, file, processed_directives) do
    processed_directives? = MapSet.member?(processed_directives, directive.name)

    if processed_directives? do
      directive_line = directive.line
      directive_col = directive.column

      message = """
      the directive `#{directive.name}` has been passed multiple times. Considering only the last value.

      Hint: remove all redundant definitions.
      """

      warning(message, file, {directive_line, directive_col})
    end
  end

  defp template_file(module) do
    if function_exported?(module, :__template_file__, 0) do
      module.__template_file__()
    else
      module.module_info() |> get_in([:compile, :source]) |> to_string()
    end
  end

  defp warning(message, file, position) do
    diagnostic(message, file, position, :warning)
  end

  defp diagnostic(message, file, position, severity) do
    %Diagnostic{
      compiler_name: "Surface",
      file: file,
      message: message,
      position: position,
      severity: severity
    }
  end
end
