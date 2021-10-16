defmodule Mix.Tasks.Surface.Init.Patcher do
  @moduledoc false

  alias Mix.Tasks.Surface.Init.ExPatcher

  @result_precedence %{
    :unpatched => 0,
    :patched => 1,
    :already_patched => 2,
    :maybe_already_patched => 3,
    :cannot_patch => 4
  }

  @results_with_message [
    :maybe_already_patched,
    :cannot_patch,
    :file_not_found,
    :cannot_read_file
  ]

  @template_folder "priv/templates/surface.init"

  def patch_files(list) do
    list = Enum.reduce(list, fn item, acc -> Map.merge(acc, item, fn _k, a, b -> a ++ b end) end)

    for {file, patches} <- list do
      patch_file(file, List.wrap(patches))
    end
  end

  def patch_code(code, patch_spec) do
    patch_spec.patch
    |> List.wrap()
    |> run_patch_funs(code)
  end

  def create_files(assigns, src_dest_list) do
    %{yes: yes} = assigns

    mapping =
      Enum.map(src_dest_list, fn {src, dest} ->
        file_name = Path.basename(src)
        {:eex, src, Path.join(dest, file_name)}
      end)

    results = copy_from(paths(), @template_folder, Map.to_list(assigns), mapping, force: yes)

    results
    |> Enum.zip(mapping)
    |> Enum.map(fn
      {true, {_, _, dest}} -> {:patched, dest, %{name: "Create #{dest}", instructions: ""}}
      {false, {_, _, dest}} -> {:already_patched, dest, %{name: "Create #{dest}", instructions: ""}}
    end)
  end

  def extract_updated_deps_from_results(patch_files_results) do
    patch_files_results
    |> List.flatten()
    |> Enum.map(fn
      {:patched, _, %{update_deps: deps}} -> deps
      _ -> []
    end)
    |> List.flatten()
  end

  def print_results(results) do
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

  defp patch_file(file, patches) do
    Mix.shell().info([:green, "* patching ", :reset, file])

    case File.read(file) do
      {:ok, code} ->
        {updated_code, results} =
          Enum.reduce(patches, {code, []}, fn patch_spec, {code, results} ->
            %{patch: patch} = patch_spec
            {result, updated_code} = patch |> List.wrap() |> run_patch_funs(code)
            {updated_code, [{result, file, patch_spec} | results]}
          end)

        File.write!(file, updated_code)
        Enum.reverse(results)

      {:error, :enoent} ->
        to_results(patches, :file_not_found, file)

      {:error, _reason} ->
        to_results(patches, :cannot_read_file, file)
    end
  end

  defp run_patch_funs(funs, code) do
    run_patch_funs(funs, code, code, :unpatched)
  end

  defp run_patch_funs([], _original_code, last_code, last_result) do
    {last_result, last_code}
  end

  defp run_patch_funs([fun | funs], original_code, last_code, last_result) do
    {result, patched_code} = last_code |> fun.() |> convert_patch_result()
    result = Enum.max_by([result, last_result], fn item -> @result_precedence[item] end)

    code =
      if result == :patched do
        patched_code
      else
        original_code
      end

    if result == :cannot_patch do
      {result, code}
    else
      run_patch_funs(funs, original_code, code, result)
    end
  end

  defp convert_patch_result(%ExPatcher{result: result, code: code}) do
    {result, code}
  end

  defp convert_patch_result(result) do
    result
  end

  defp to_results(patches, status, file) do
    Enum.map(patches, fn patch_spec ->
      {status, file, patch_spec}
    end)
  end

  defp paths(), do: [".", :surface]

  # Copied from https://github.com/phoenixframework/phoenix/blob/adfaac06992323224f94a471f5d7b95aca4c3156/lib/mix/phoenix.ex#L29
  # so we could pass the `opts` to `create_file`
  defp copy_from(apps, source_dir, binding, mapping, opts) when is_list(mapping) do
    roots = Enum.map(apps, &to_app_source(&1, source_dir))

    for {format, source_file_path, target} <- mapping do
      source =
        Enum.find_value(roots, fn root ->
          source = Path.join(root, source_file_path)
          if File.exists?(source), do: source
        end) || raise "could not find #{source_file_path} in any of the sources"

      case format do
        :text ->
          Mix.Generator.create_file(target, File.read!(source), opts)

        :eex ->
          Mix.Generator.create_file(target, EEx.eval_file(source, binding), opts)

        :new_eex ->
          if File.exists?(target) do
            :ok
          else
            Mix.Generator.create_file(target, EEx.eval_file(source, binding), opts)
          end
      end
    end
  end

  defp to_app_source(path, source_dir) when is_binary(path),
    do: Path.join(path, source_dir)

  defp to_app_source(app, source_dir) when is_atom(app),
    do: Application.app_dir(app, source_dir)
end
