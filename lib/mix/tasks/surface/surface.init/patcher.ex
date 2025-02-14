defmodule Mix.Tasks.Surface.Init.Patcher do
  @moduledoc false

  alias Mix.Tasks.Surface.Init.ExPatcher

  @template_folder "priv/templates/surface.init"

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

  def patch_file(file, patches, assigns) do
    log(:patching, file, fn ->
      case File.read(file) do
        {:ok, code} ->
          {updated_code, results} =
            Enum.reduce(patches, {code, []}, fn patch_spec, {code, results} ->
              {result, updated_code} = patch_code(code, patch_spec)
              {updated_code, [{result, file, patch_spec} | results]}
            end)

          unless assigns.dry_run do
            File.write!(file, updated_code)
          end

          Enum.reverse(results)

        {:error, :enoent} ->
          to_results(patches, :file_not_found, file)

        {:error, _reason} ->
          to_results(patches, :cannot_read_file, file)
      end
    end)
  end

  def delete_file(file, assigns) do
    patch_spec = %{name: "Delete #{file}", instructions: ""}

    log(:deleting, file, fn ->
      if File.exists?(file) do
        unless assigns.dry_run do
          File.rm!(file)
        end

        {:patched, file, patch_spec}
      else
        {:already_patched, file, patch_spec}
      end
    end)
  end

  def create_file(source_file_path, target, assigns) do
    root = Application.app_dir(:surface, @template_folder)
    source = Path.join(root, source_file_path)

    patch_spec = %{name: "Create #{target}", instructions: ""}

    log(:creating, target, fn ->
      contents = EEx.eval_file(source, Map.to_list(assigns))

      if overwrite?(target, contents, assigns) do
        unless assigns.dry_run do
          File.mkdir_p!(Path.dirname(target))
          File.write!(target, contents)
        end

        {:patched, target, patch_spec}
      else
        {:already_patched, target, patch_spec}
      end
    end)
  end

  def overwrite?(path, contents, assigns) do
    case File.read(path) do
      {:ok, binary} ->
        if binary == IO.iodata_to_binary(contents) do
          false
        else
          if assigns.yes do
            true
          else
            full = Path.expand(path)
            Mix.shell().yes?(Path.relative_to_cwd(full) <> " already exists, overwrite?")
          end
        end

      _ ->
        true
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
    for patch_spec <- patches, status not in Map.get(patch_spec, :ignore_when, []) do
      {status, file, patch_spec}
    end
  end

  defp log(action, file, fun) do
    result = fun.()

    if result != [] do
      prefix = "* #{action} "
      Mix.shell().info([:green, prefix, :reset, file])

      skipped_postfix =
        case result |> List.wrap() |> Enum.split_with(&match?({:patched, _, _}, &1)) do
          {[], _not_patched} ->
            [:yellow, " (skipped)", :reset]

          {_patched, []} ->
            []

          {patched, not_patched} ->
            n_not_patched = length(not_patched)
            total = n_not_patched + length(patched)
            [:yellow, " (skipped #{n_not_patched} of #{total} changes)", :reset]
        end

      if skipped_postfix != [] do
        Mix.shell().info([IO.ANSI.cursor_up(), :clear_line, :yellow, prefix, :reset, file] ++ skipped_postfix)
      end
    end

    result
  end
end
