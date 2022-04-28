defmodule Mix.Tasks.Surface.Init.ProjectPatcher do
  @moduledoc false

  @callback specs(assigns :: map()) :: list()

  alias Mix.Tasks.Surface.Init.Patcher

  @results_with_message [
    :maybe_already_patched,
    :cannot_patch,
    :file_not_found,
    :cannot_read_file
  ]

  def run(project_patchers, assigns) do
    results =
      project_patchers
      |> Enum.flat_map(& &1.specs(assigns))
      |> run_specs(assigns)

    updated_deps = extract_updated_deps_from_results(results)

    results = List.flatten(results)
    n_patches = length(results)
    results_by_type = Enum.group_by(results, &elem(&1, 0))
    n_patches_applied = length(results_by_type[:patched] || [])
    n_patches_already_patched = length(results_by_type[:already_patched] || [])
    n_patches_skipped = n_patches - n_patches_applied
    n_files = Enum.map(results, fn {_, file, _} -> file end) |> Enum.uniq() |> length()

    patches_with_messages =
      Enum.reduce(@results_with_message, [], fn result, acc -> acc ++ (results_by_type[result] || []) end)

    %{
      results: List.flatten(results),
      updated_deps: updated_deps,
      n_patches: n_patches,
      n_files: n_files,
      n_patches_applied: n_patches_applied,
      n_patches_already_patched: n_patches_already_patched,
      n_patches_skipped: n_patches_skipped,
      patches_with_messages: patches_with_messages
    }
  end

  defp run_specs(specs, assigns) do
    {patch_specs, other_specs} = Enum.split_with(specs, &match?({:patch, _, _}, &1))

    grouped_patch_specs =
      patch_specs
      |> Enum.group_by(fn {_, file, _} -> file end, fn {_, _, patches} -> patches end)
      |> Enum.map(fn {k, v} -> {:patch, k, List.flatten(v)} end)

    Enum.map(grouped_patch_specs ++ other_specs, &run_spec(&1, assigns))
  end

  defp run_spec({:create, src, dest}, assigns) do
    file_name = Path.basename(src)
    target = Path.join(dest, file_name)
    Patcher.create_file(src, target, assigns)
  end

  defp run_spec({:delete, file}, assigns) do
    Patcher.delete_file(file, assigns)
  end

  defp run_spec({:patch, file, patchers}, assigns) do
    Patcher.patch_file(file, List.wrap(patchers), assigns)
  end

  defp extract_updated_deps_from_results(patch_files_results) do
    patch_files_results
    |> List.flatten()
    |> Enum.map(fn
      {:patched, _, %{update_deps: deps}} -> deps
      _ -> []
    end)
    |> List.flatten()
  end
end
