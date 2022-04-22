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

  def patch_code(code, patch_spec) do
    patch_spec.patch
    |> List.wrap()
    |> run_patch_funs(code)
  end

  def patch_file(file, patches) do
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

  # Copied from https://github.com/phoenixframework/phoenix/blob/adfaac06992323224f94a471f5d7b95aca4c3156/lib/mix/phoenix.ex#L29
  # so we could pass the `opts` to `create_file`
  def copy_from(apps, source_dir, binding, mapping, opts) when is_list(mapping) do
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

  defp to_app_source(path, source_dir) when is_binary(path),
    do: Path.join(path, source_dir)

  defp to_app_source(app, source_dir) when is_atom(app),
    do: Application.app_dir(app, source_dir)
end
