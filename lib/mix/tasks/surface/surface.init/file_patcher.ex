defmodule Mix.Tasks.Surface.Init.FilePatcher do
  @moduledoc false

  alias Mix.Tasks.Surface.Init.ExPatcher

  def print_patch_results(results) do
    results = List.flatten(results)
    n_patches = length(results)
    n_files = Enum.map(results, fn {_, _, file, _} -> file end) |> Enum.uniq() |> length()
    results_by_type = Enum.group_by(results, &elem(&1, 0))
    n_patches_applied = length(results_by_type[:patched] || [])
    n_patches_already_patched = length(results_by_type[:already_patched] || [])
    n_patches_skipped = n_patches - n_patches_applied

    patches_with_messages =
      (results_by_type[:maybe_already_patched] || []) ++
        (results_by_type[:code_not_found] || []) ++
        (results_by_type[:file_modified] || []) ++
        (results_by_type[:file_not_found] || []) ++
        (results_by_type[:cannot_read_file] || [])

    n_patches_with_messages = length(patches_with_messages)

    Mix.shell().info(["\nFinished running #{n_patches} patches against #{n_files} files."])

    if n_patches_with_messages > 0 do
      Mix.shell().info([:yellow, "#{n_patches_with_messages} messages emitted."])
    end

    summary = "#{n_patches_applied} patches applied, #{n_patches_skipped} skipped."

    if n_patches_already_patched == n_patches do
      Mix.shell().info([:yellow, summary])
      Mix.shell().info([:cyan, "It looks like this project has already been patched."])
    else
      Mix.shell().info([:green, summary])
    end

    print_opts = [doc_bold: [:yellow], doc_underline: [:italic, :yellow], width: 90]

    patches_with_messages
    |> Enum.with_index(1)
    |> Enum.each(fn {{result, name, file, instructions}, index} ->
      reason =
        case result do
          :maybe_already_patched ->
            "it seems the patch has already been applied or manually set up"

          :code_not_found ->
            "unexpected structure of the code"

          :file_modified ->
            "the file has been modified by the user and it's no longer safe to automatically patch it"

          :file_not_found ->
            "file not found"

          :cannot_read_file ->
            "cannot read file"
        end

      IO.ANSI.Docs.print_headings(["Message ##{index}"], print_opts)

      message = """
      Patch _"#{name}"_ was not applied to `#{file}`.

      Reason: *#{reason}.*

      If you believe you still need to apply this patch, you must do it manually with the following instructions:

      #{instructions}
      """

      IO.ANSI.Docs.print(message, "text/markdown", print_opts)
    end)
  end

  def patch_files(list) do
    for {file, patches} <- list do
      patch_file(file, List.wrap(patches))
    end
  end

  def patch_file(file, patches) do
    Mix.shell().info([:green, "* Patching ", :reset, file])

    case File.read(file) do
      {:ok, code} ->
        {updated_code, results} =
          Enum.reduce(patches, {code, []}, fn %{patch: patch, name: name, instructions: instructions},
                                              {code, results} ->
            {result, updated_code} = patch |> List.wrap() |> run_patch_funs(code)
            {updated_code, [{result, name, file, instructions} | results]}
          end)

        File.write!(file, updated_code)
        Enum.reverse(results)

      {:error, :enoent} ->
        to_results(patches, :file_not_found, file)

      {:error, _reason} ->
        to_results(patches, :cannot_read_file, file)
    end
  end

  def run_patch_funs(funs, code) do
    Enum.reduce_while(funs, {:unpatched, code}, fn
      fun, {result, code} when result in [:patched, :unpatched] ->
        {:cont, code |> fun.() |> convert_patch_result()}

      _fun, result ->
        {:halt, result}
    end)
  end

  defp convert_patch_result(%ExPatcher{code: code, result: result}) do
    {result, code}
  end

  defp convert_patch_result(result) do
    result
  end

  defp to_results(patches, status, file) do
    Enum.map(patches, fn %{name: name, instructions: instructions} ->
      {status, name, file, instructions}
    end)
  end
end
