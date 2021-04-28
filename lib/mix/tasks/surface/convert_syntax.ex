defmodule Mix.Tasks.Surface.ConvertSyntax do
  @shortdoc "Converts .sface files and ~H sigils from pre-v0.5 to v0.5 syntax"

  @moduledoc """
  Converts .sface files and ~H sigils from pre-v0.5 to v0.5 syntax.

      mix surface.convert_syntax "lib/**/*.{ex,exs}" "test/**/*.{ex,exs}"

  ## Task-specific options

  The Surface formatter accepts a couple of the same task-specific options as `mix format`.
  Here are some examples of using these options:

  ```bash
  $ mix surface.convert_syntax --dot-formatter path/to/.formatter.exs
  ```

  You can also use the same syntax as `mix convert_syntax` for specifying which files to
  convert:

  ```bash
  $ mix surface.convert_syntax path/to/file.ex "lib/**/*.{ex,exs}" "test/**/*.{ex,exs}"
  ```
  """

  use Mix.Task

  defp format_string(string, opts) do
    IO.inspect opts, label: "================ opts"
    Function.identity(string)
  end

  #
  # Functions unique to surface.format (Everything else is taken from Mix.Tasks.Format)
  #

  defp convert_file_contents!(file, input, opts) do
    case Path.extname(file) do
      ".sface" ->
        format_string(input, opts)

      _ ->
        convert_ex_string!(input, opts)
    end
  end

  defp convert_ex_string!(input, opts) do
    ~r/\n( *)~H"""(.*?)"""/s
    |> Regex.replace(input, fn _match, indentation, surface_code ->
      # Indent the entire ~H sigil contents based on the indentation of `~H"""`
      tabs =
        indentation
        |> String.length()
        |> Kernel.div(2)

      opts = Keyword.put(opts, :indent, tabs)

      "\n#{indentation}~H\"\"\"#{
        surface_code
        |> format_string(opts)
      }\"\"\""
    end)
  end

  #
  # The below functions are taken directly from Mix.Tasks.Format with insignificant modification
  #

  @switches [
    dot_formatter: :string,
    dry_run: :boolean
  ]

  @impl true
  def run(args) do
    {opts, args} = OptionParser.parse!(args, strict: @switches)
      |> IO.inspect(label: "=============================== -1")
    {dot_formatter, formatter_opts} = eval_dot_formatter(opts)
      |> IO.inspect(label: "=============================== 0")

    args
    |> expand_args(dot_formatter, {formatter_opts, []})
    |> IO.inspect(label: "=============================== C")
    |> Task.async_stream(&convert_file(&1, opts), ordered: false, timeout: 30000)
    |> Enum.reduce([], &collect_status/2)
    |> check!()
  end

  defp convert_file({file, formatter_opts}, task_opts) do
    {input, extra_opts} = read_file(file)
    formatted = convert_file_contents!(file, input, extra_opts ++ formatter_opts)
    output = IO.iodata_to_binary([formatted])

    dry_run? = Keyword.get(task_opts, :dry_run, false)

    cond do
      dry_run? ->
        :ok

      true ->
        write_or_print(file, input, output)
    end
  rescue
    exception ->
      {:exit, file, exception, __STACKTRACE__}
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

  defp collect_status({:ok, :ok}, exits), do: exits

  defp collect_status({:ok, {:exit, _, _, _} = exit}, exits) do
    [exit | exits]
  end

  defp check!([]) do
    :ok
  end

  defp check!([{:exit, :stdin, exception, stacktrace} | _]) do
    Mix.shell().error("mix surface.convert_syntax failed for stdin")
    reraise exception, stacktrace
  end

  defp check!([{:exit, file, exception, stacktrace} | _]) do
    Mix.shell().error("mix surface.convert_syntax failed for file: #{Path.relative_to_cwd(file)}")
    reraise exception, stacktrace
  end
end
