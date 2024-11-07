defmodule Mix.Tasks.Compile.Surface.Definitions do
  @moduledoc false

  @default_output_dir "#{Mix.Project.build_path()}/definitions/"

  def run(specs, opts \\ []) do
    generate_definitions? = Keyword.get(opts, :generate_definitions, true)

    if generate_definitions? do
      do_run(specs, opts)
    else
      []
    end
  end

  defp do_run(specs, opts) do
    output_dir = Keyword.get(opts, :definitions_output_dir, @default_output_dir)
    generate_definitions(specs, output_dir)
    []
  end

  defp generate_definitions(specs, output_dir) do
    definitions =
      for %{type: type} = spec <- specs do
        case type do
          :surface ->
            %{
              name: spec.module,
              alias: get_alias(spec.module)
            }

          type when type in [:def, :defp] ->
            %{
              name: "#{spec.module}.#{spec.func}",
              alias: ".#{spec.func}"
            }
        end
      end
      |> Enum.sort_by(& &1.name)

    components_by_name =
      for %{type: type} = spec <- specs, into: %{} do
        case type do
          :surface ->
            {spec.module, spec}

          type when type in [:def, :defp] ->
            {"#{spec.module}.#{spec.func}", spec}
        end
      end

    File.mkdir_p!(output_dir)

    components_file = Path.join(output_dir, "components.json")
    # TODO: add config `definitions_pretty`, default: false
    components_content = Phoenix.json_library().encode!(definitions, pretty: true)
    File.write!(components_file, components_content)

    components_by_name_file = Path.join(output_dir, "components_by_name.json")
    components_by_name_content = Phoenix.json_library().encode!(components_by_name, pretty: true)
    File.write!(components_by_name_file, components_by_name_content)
  end

  defp get_alias(component) do
    component
    |> String.split(".")
    |> List.last()
  end
end
