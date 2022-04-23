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

    print_results(results)

    updated_deps = extract_updated_deps_from_results(results)

    {:ok, updated_deps}
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
    %{yes: yes} = assigns

    file_name = Path.basename(src)
    target = Path.join(dest, file_name)
    Patcher.create_file(src, target, assigns, force: yes)
  end

  defp run_spec({:delete, file}, _assigns) do
    Patcher.delete_file(file)
  end

  defp run_spec({:patch, file, patchers}, _assigns) do
    Patcher.patch_file(file, List.wrap(patchers))
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

  defp print_results(results) do
    results = List.flatten(results)
    n_patches = length(results)
    n_files = Enum.map(results, fn {_, file, _} -> file end) |> Enum.uniq() |> length()
    results_by_type = Enum.group_by(results, &elem(&1, 0))
    n_patches_applied = length(results_by_type[:patched] || [])
    n_patches_already_patched = length(results_by_type[:already_patched] || [])
    n_patches_skipped = n_patches - n_patches_applied

    patches_with_messages =
      Enum.reduce(@results_with_message, [], fn result, acc -> acc ++ (results_by_type[result] || []) end)

    n_patches_with_messages = length(patches_with_messages)

    Mix.shell().info(["\nFinished running #{n_patches} patches for #{n_files} files."])

    if n_patches_with_messages > 0 do
      Mix.shell().info([:yellow, "#{n_patches_with_messages} messages emitted."])
    end

    summary = "#{n_patches_applied} changes applied, #{n_patches_skipped} skipped."

    if n_patches_already_patched == n_patches do
      Mix.shell().info([:yellow, summary])
      Mix.shell().info([:cyan, "It looks like this project has already been patched."])
    else
      Mix.shell().info([:green, summary])
    end

    print_opts = [doc_bold: [:yellow], doc_underline: [:italic, :yellow], width: 90]

    patches_with_messages
    |> Enum.with_index(1)
    |> Enum.each(fn {{result, file, %{name: name, instructions: instructions}}, index} ->
      {reason, details} =
        case result do
          :maybe_already_patched ->
            {"it seems the patch has already been applied or manually set up", ""}

          :cannot_patch ->
            {"unexpected file content",
             """

             *Either the original file has changed or it has been modified by the user \
             and it's no longer safe to automatically patch it.*
             """}

          :file_not_found ->
            {"file not found", ""}

          :cannot_read_file ->
            {"cannot read file", ""}
        end

      IO.ANSI.Docs.print_headings(["Message ##{index}"], print_opts)

      message = """
      Patch _"#{name}"_ was not applied to `#{file}`.

      Reason: *#{reason}.*
      #{details}
      If you believe you still need to apply this patch, you must do it manually with the following instructions:

      #{instructions}
      """

      IO.ANSI.Docs.print(message, "text/markdown", print_opts)
    end)
  end
end
