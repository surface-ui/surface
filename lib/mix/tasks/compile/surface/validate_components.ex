defmodule Mix.Tasks.Compile.Surface.ValidateComponents do
  alias Mix.Task.Compiler.Diagnostic
  alias Surface.AST
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
    file = module.module_info() |> get_in([:compile, :source]) |> to_string()

    for component_call <- components_calls do
      validate_properties(file, component_call)
    end
    |> Enum.reject(&is_nil/1)
  end

  defp validate_properties(file, component_call) do
    module = component_call.component
    props = component_call.props
    node_alias = component_call.node_alias
    line = component_call.line
    directives = component_call.directives

    has_directive_props? = Enum.any?(directives, &match?(%AST.Directive{name: :props}, &1))

    if not has_directive_props? and function_exported?(module, :__props__, 0) do
      existing_props_names = Enum.map(props, & &1.name)
      required_props_names = module.__required_props_names__()
      missing_props_names = required_props_names -- existing_props_names

      for prop_name <- missing_props_names do
        message = "Missing required property \"#{prop_name}\" for component <#{node_alias}>"

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

        error(message, file, line)
      end
    end
  end

  defp error(message, file, line) do
    # TODO: Provide column information in diagnostic once we depend on Elixir v1.13+
    %Diagnostic{
      compiler_name: "Surface",
      file: file,
      message: message,
      position: line,
      severity: :error
    }
  end
end
