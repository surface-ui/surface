defmodule Mix.Tasks.Surface.Format do
  @shortdoc "Formats Surface ~F sigils and .sface files in the given files/patterns"

  @moduledoc """
  > #### Formatter Plugin Preferred {: .tip}
  >
  > To format Surface code using Elixir 1.13 or later, use
  > `Surface.Formatter.Plugin`.

  Formats Surface `~F` sigils and `.sface` files in the given files and patterns.

  ```bash
  $ mix surface.format "lib/**/*.{ex,exs}" "test/**/*.{ex,exs}"
  $ cat path/to/file.ex | mix surface.format -
  ```

  Takes the same options as `mix format` except for `--check-equivalent`.

  ## Formatting options

  Like `mix format`, the Surface formatter reads a `.formatter.exs` file in the
  current directory for formatter configuration. The Surface formatter accepts
  the same options as `mix format`. Read more about the expected format of
  `.formatter.exs` and the shared configuration options
  [documented here](https://hexdocs.pm/mix/main/Mix.Tasks.Format.html#module-formatting-options).

  The Surface formatter also takes the following two additional options
  specified in `.formatter.exs`:

    - `:surface_line_length` overrides `:line_length` only for `mix surface.format`
      (`:line_length` is used otherwise, or defaults to 98)
    - `:surface_inputs` overrides `:inputs` only for `mix surface.format`
      (`:inputs` is used otherwise)

  ## Task-specific options

  The Surface formatter accepts the same task-specific options as `mix format`.
  [Read documentation for the options documented here.](https://hexdocs.pm/mix/main/Mix.Tasks.Format.html#module-task-specific-options).

  For quick reference, here are some examples of using these options:

  ```bash
  $ mix surface.format --check-formatted
  ** (Mix) mix surface.format failed due to --check-formatted.
  The following files are not formatted:
    * path/to/component.ex
    * path/to/file.sface
  ```

  ```bash
  $ mix surface.format --dry-run
  ```

  ```bash
  $ mix surface.format --dot-formatter path/to/.formatter.exs
  ```

  You can also use the same syntax as `mix format` for specifying which files to
  format:

  ```bash
  $ mix surface.format path/to/file.ex "lib/**/*.{ex,exs}" "test/**/*.{ex,exs}"
  ```
  """

  use Mix.Task

  alias Surface.Formatter

  #
  # Functions unique to surface.format (Everything else is taken from Mix.Tasks.Format)
  #

  defp format_file_contents!(:stdin, input, opts) do
    # determine whether the input is Elixir or Surface code by checking if `Code.string_to_quoted` can parse it
    case Code.string_to_quoted(input) do
      {:ok, _} ->
        format_ex_string!(input, opts)

      {:error, _} ->
        Formatter.format_string!(input, opts)
    end
  end

  defp format_file_contents!(file, input, opts) do
    case Path.extname(file) do
      ".sface" ->
        Formatter.format_string!(input, opts)

      _ ->
        format_ex_string!(input, opts)
    end
  end

  defp format_ex_string!(input, opts) do
    string =
      ~r/\n( *)~F"""(.*?)"""/s
      |> Regex.replace(input, fn _match, indentation, surface_code ->
        # Indent the entire ~F sigil contents based on the indentation of `~F"""`
        tabs =
          indentation
          |> String.length()
          |> Kernel.div(2)

        opts = Keyword.put(opts, :indent, tabs)

        "\n#{indentation}~F\"\"\"\n#{Formatter.format_string!(surface_code, opts)}#{indentation}\"\"\""
      end)

    # We do not match on ~F"..." sigils where the first character is `\`
    # in order to allow for a use case in surface_site, where Surface
    # code examples are being rendered inside a Markdown component and
    # contains the string: `~F"\""`
    string =
      Regex.replace(~r/~F\"([^\"\\].*?)\"/s, string, fn _match, code ->
        "~F\"#{Formatter.format_string!(code, opts)}\""
      end)

    string =
      Regex.replace(~r/~F\[(.*?)\]/s, string, fn _match, code ->
        "~F[#{Formatter.format_string!(code, opts)}]"
      end)

    string =
      Regex.replace(~r/~F\((.*?)\)/s, string, fn _match, code ->
        "~F(#{Formatter.format_string!(code, opts)})"
      end)

    Regex.replace(~r/~F\{(.*?)\}/s, string, fn _match, code ->
      "~F{#{Formatter.format_string!(code, opts)}}"
    end)
  end

  #
  # The below functions are taken directly from Mix.Tasks.Format with insignificant modification
  #

  @switches [
    check_formatted: :boolean,
    dot_formatter: :string,
    dry_run: :boolean
  ]

  @manifest "cached_dot_formatter"
  @manifest_vsn 1

  @impl true
  def run(args) do
    {opts, args} = OptionParser.parse!(args, strict: @switches)
    {dot_formatter, formatter_opts} = eval_dot_formatter(opts)

    {{formatter_opts, subdirectories}, _sources} =
      eval_deps_and_subdirectories(dot_formatter, [], formatter_opts, [dot_formatter])

    # surface_line_length can be used to override the line_length option
    formatter_opts =
      if line_length = formatter_opts[:surface_line_length] do
        Keyword.put(formatter_opts, :line_length, line_length)
      else
        formatter_opts
      end

    args
    |> expand_args(dot_formatter, {formatter_opts, subdirectories})
    |> Task.async_stream(&format_file(&1, opts), ordered: false, timeout: 30000)
    |> Enum.reduce({[], [], []}, &collect_status/2)
    |> check!()
  end

  defp format_file({file, formatter_opts}, task_opts) do
    {input, extra_opts} = read_file(file)
    formatted = format_file_contents!(file, input, extra_opts ++ formatter_opts)
    output = IO.iodata_to_binary([formatted])

    check_equivalent? = Keyword.get(task_opts, :check_equivalent, false)
    check_formatted? = Keyword.get(task_opts, :check_formatted, false)
    dry_run? = Keyword.get(task_opts, :dry_run, false)

    cond do
      check_equivalent? and not equivalent?(input, output) ->
        {:not_equivalent, file}

      check_formatted? ->
        if input == output, do: :ok, else: {:not_formatted, file}

      dry_run? ->
        :ok

      true ->
        write_or_print(file, input, output)
    end
  rescue
    exception ->
      {:exit, file, exception, __STACKTRACE__}
  end

  # This function reads exported configuration from the imported
  # dependencies and subdirectories and deals with caching the result
  # of reading such configuration in a manifest file.
  defp eval_deps_and_subdirectories(dot_formatter, prefix, formatter_opts, sources) do
    deps = Keyword.get(formatter_opts, :import_deps, [])
    subs = Keyword.get(formatter_opts, :subdirectories, [])

    if not is_list(deps) do
      Mix.raise("Expected :import_deps to return a list of dependencies, got: #{inspect(deps)}")
    end

    if not is_list(subs) do
      Mix.raise("Expected :subdirectories to return a list of directories, got: #{inspect(subs)}")
    end

    if deps == [] and subs == [] do
      {{formatter_opts, []}, sources}
    else
      manifest = Path.join(Mix.Project.manifest_path(), @manifest)

      maybe_cache_in_manifest(dot_formatter, manifest, fn ->
        {subdirectories, sources} = eval_subs_opts(subs, prefix, sources)
        {{eval_deps_opts(formatter_opts, deps), subdirectories}, sources}
      end)
    end
  end

  defp eval_deps_opts(formatter_opts, deps) do
    deps_paths = Mix.Project.deps_paths()

    parenless_calls =
      for dep <- deps,
          dep_path = assert_valid_dep_and_fetch_path(dep, deps_paths),
          dep_dot_formatter = Path.join(dep_path, ".formatter.exs"),
          File.regular?(dep_dot_formatter),
          dep_opts = eval_file_with_keyword_list(dep_dot_formatter),
          parenless_call <- dep_opts[:export][:locals_without_parens] || [],
          uniq: true,
          do: parenless_call

    Keyword.update(
      formatter_opts,
      :locals_without_parens,
      parenless_calls,
      &(&1 ++ parenless_calls)
    )
  end

  defp eval_subs_opts(subs, prefix, sources) do
    {subs, sources} =
      Enum.flat_map_reduce(subs, sources, fn sub, sources ->
        prefix = Path.join(prefix ++ [sub])
        {Path.wildcard(prefix), [Path.join(prefix, ".formatter.exs") | sources]}
      end)

    Enum.flat_map_reduce(subs, sources, fn sub, sources ->
      sub_formatter = Path.join(sub, ".formatter.exs")

      if File.exists?(sub_formatter) do
        formatter_opts = eval_file_with_keyword_list(sub_formatter)

        {formatter_opts_and_subs, sources} =
          eval_deps_and_subdirectories(:in_memory, [sub], formatter_opts, sources)

        {[{sub, formatter_opts_and_subs}], sources}
      else
        {[], sources}
      end
    end)
  end

  defp assert_valid_dep_and_fetch_path(dep, deps_paths) when is_atom(dep) do
    case Map.fetch(deps_paths, dep) do
      {:ok, path} ->
        if File.dir?(path) do
          path
        else
          Mix.raise(
            "Unavailable dependency #{inspect(dep)} given to :import_deps in the formatter configuration. " <>
              "The dependency cannot be found in the file system, please run \"mix deps.get\" and try again"
          )
        end

      :error ->
        Mix.raise(
          "Unknown dependency #{inspect(dep)} given to :import_deps in the formatter configuration. " <>
            "The dependency is not listed in your mix.exs for environment #{inspect(Mix.env())}"
        )
    end
  end

  defp maybe_cache_in_manifest(dot_formatter, manifest, fun) do
    cond do
      is_nil(Mix.Project.get()) or dot_formatter != ".formatter.exs" -> fun.()
      entry = read_manifest(manifest) -> entry
      true -> write_manifest!(manifest, fun.())
    end
  end

  defp read_manifest(manifest) do
    with {:ok, binary} <- File.read(manifest),
         {:ok, {@manifest_vsn, entry, sources}} <- safe_binary_to_term(binary),
         expanded_sources = Enum.flat_map(sources, &Path.wildcard(&1, match_dot: true)),
         false <- Mix.Utils.stale?([Mix.Project.config_mtime() | expanded_sources], [manifest]) do
      {entry, sources}
    else
      _ -> nil
    end
  end

  defp safe_binary_to_term(binary) do
    {:ok, :erlang.binary_to_term(binary)}
  rescue
    _ -> :error
  end

  defp write_manifest!(manifest, {entry, sources}) do
    File.mkdir_p!(Path.dirname(manifest))
    File.write!(manifest, :erlang.term_to_binary({@manifest_vsn, entry, sources}))
    {entry, sources}
  end

  defp eval_dot_formatter(opts) do
    cond do
      dot_formatter = opts[:dot_formatter] ->
        {dot_formatter, eval_file_with_keyword_list(dot_formatter)}

      File.regular?(".formatter.exs") ->
        {".formatter.exs", eval_file_with_keyword_list(".formatter.exs")}

      true ->
        {".formatter.exs", []}
    end
  end

  defp eval_file_with_keyword_list(path) do
    {opts, _} = Code.eval_file(path)

    unless Keyword.keyword?(opts) do
      Mix.raise("Expected #{inspect(path)} to return a keyword list, got: #{inspect(opts)}")
    end

    opts
  end

  defp read_file(:stdin) do
    {IO.stream(:stdio, :line) |> Enum.to_list() |> IO.iodata_to_binary(), file: "stdin"}
  end

  defp read_file(file) do
    {File.read!(file), file: file}
  end

  defp expand_args([], dot_formatter, formatter_opts_and_subs) do
    if no_entries_in_formatter_opts?(formatter_opts_and_subs) do
      Mix.raise(
        "Expected one or more files/patterns to be given to mix format " <>
          "or for a .formatter.exs file to exist with an :inputs, :surface_inputs or :subdirectories key"
      )
    end

    dot_formatter
    |> expand_dot_inputs([], formatter_opts_and_subs, %{})
    |> Enum.map(fn {file, {_dot_formatter, formatter_opts}} -> {file, formatter_opts} end)
  end

  defp expand_args(files_and_patterns, _dot_formatter, {formatter_opts, subs}) do
    files =
      for file_or_pattern <- files_and_patterns,
          file <- stdin_or_wildcard(file_or_pattern),
          uniq: true,
          do: file

    if files == [] do
      Mix.raise(
        "Could not find a file to format. The files/patterns given to command line " <>
          "did not point to any existing file. Got: #{inspect(files_and_patterns)}"
      )
    end

    for file <- files do
      if file == :stdin do
        {file, formatter_opts}
      else
        split = file |> Path.relative_to_cwd() |> Path.split()
        {file, find_formatter_opts_for_file(split, {formatter_opts, subs})}
      end
    end
  end

  defp expand_dot_inputs(dot_formatter, prefix, {formatter_opts, subs}, acc) do
    if no_entries_in_formatter_opts?({formatter_opts, subs}) do
      Mix.raise("Expected :inputs, :surface_inputs or :subdirectories key in #{dot_formatter}")
    end

    map =
      for input <- List.wrap(formatter_opts[:surface_inputs] || formatter_opts[:inputs]),
          file <- Path.wildcard(Path.join(prefix ++ [input]), match_dot: true),
          do: {expand_relative_to_cwd(file), {dot_formatter, formatter_opts}},
          into: %{}

    acc =
      Map.merge(acc, map, fn file, {dot_formatter1, _}, {dot_formatter2, formatter_opts} ->
        Mix.shell().error(
          "Both #{dot_formatter1} and #{dot_formatter2} specify the file " <>
            "#{Path.relative_to_cwd(file)} in their :inputs or :surface_inputs option. To resolve the " <>
            "conflict, the configuration in #{dot_formatter1} will be ignored. " <>
            "Please change the list of :inputs (or :surface_inputs) in one of the formatter files so only " <>
            "one of them matches #{Path.relative_to_cwd(file)}"
        )

        {dot_formatter2, formatter_opts}
      end)

    Enum.reduce(subs, acc, fn {sub, formatter_opts_and_subs}, acc ->
      sub_formatter = Path.join(sub, ".formatter.exs")
      expand_dot_inputs(sub_formatter, [sub], formatter_opts_and_subs, acc)
    end)
  end

  defp expand_relative_to_cwd(path) do
    case File.cwd() do
      {:ok, cwd} -> Path.expand(path, cwd)
      _ -> path
    end
  end

  defp find_formatter_opts_for_file(split, {formatter_opts, subs}) do
    Enum.find_value(subs, formatter_opts, fn {sub, formatter_opts_and_subs} ->
      if List.starts_with?(split, Path.split(sub)) do
        find_formatter_opts_for_file(split, formatter_opts_and_subs)
      end
    end)
  end

  defp stdin_or_wildcard("-"), do: [:stdin]
  defp stdin_or_wildcard(path), do: path |> Path.expand() |> Path.wildcard(match_dot: true)

  defp no_entries_in_formatter_opts?({formatter_opts, subs}) do
    is_nil(formatter_opts[:inputs]) and is_nil(formatter_opts[:surface_inputs]) and subs == []
  end

  defp write_or_print(file, input, output) do
    cond do
      file == :stdin -> IO.write(output)
      input == output -> :ok
      true -> File.write!(file, output)
    end

    :ok
  end

  defp collect_status({:ok, :ok}, acc), do: acc

  defp collect_status({:ok, {:exit, _, _, _} = exit}, {exits, not_equivalent, not_formatted}) do
    {[exit | exits], not_equivalent, not_formatted}
  end

  defp collect_status({:ok, {:not_equivalent, file}}, {exits, not_equivalent, not_formatted}) do
    {exits, [file | not_equivalent], not_formatted}
  end

  defp collect_status({:ok, {:not_formatted, file}}, {exits, not_equivalent, not_formatted}) do
    {exits, not_equivalent, [file | not_formatted]}
  end

  defp check!({[], [], []}) do
    :ok
  end

  defp check!({[{:exit, :stdin, exception, stacktrace} | _], _not_equivalent, _not_formatted}) do
    Mix.shell().error("mix surface.format failed for stdin")
    reraise exception, stacktrace
  end

  defp check!({[{:exit, file, exception, stacktrace} | _], _not_equivalent, _not_formatted}) do
    Mix.shell().error("mix surface.format failed for file: #{Path.relative_to_cwd(file)}")
    reraise exception, stacktrace
  end

  defp check!({_exits, [_ | _] = not_equivalent, _not_formatted}) do
    Mix.raise("""
    mix surface.format failed due to --check-equivalent.
    The following files are not equivalent:
    #{to_bullet_list(not_equivalent)}
    Please report this bug with the input files at https://github.com/surface-ui/surface_formatter/issues
    """)
  end

  defp check!({_exits, _not_equivalent, [_ | _] = not_formatted}) do
    Mix.raise("""
    mix surface.format failed due to --check-formatted.
    The following files are not formatted:
    #{to_bullet_list(not_formatted)}
    """)
  end

  defp to_bullet_list(files) do
    Enum.map_join(files, "\n", &"  * #{&1 |> to_string() |> Path.relative_to_cwd()}")
  end

  defp equivalent?(input, output) do
    input == output
  end
end
