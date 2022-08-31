defmodule Mix.Tasks.Surface.Convert do
  @shortdoc "Converts .sface files and ~F sigils from v0.7 to v0.8 syntax"

  @moduledoc """
  Converts .sface files and ~F sigils from v0.7 to v0.8 syntax.

      mix surface.convert "lib/**/*.{ex,exs,sface}" "test/**/*.{ex,exs}"

  Please read the [Migration Guide](https://github.com/surface-ui/surface/blob/main/MIGRATING.md)
  before running the converter and make sure you follow all required steps for a successful migration.

  ## Task-specific options

  The Surface formatter accepts a couple of the same task-specific options as `mix format`.
  Here are some examples of using these options:

  ```bash
  $ mix surface.convert --dot-formatter path/to/.formatter.exs
  ```

  You can also use the same syntax as `mix format` for specifying which files to
  convert:

  ```bash
  $ mix surface.convert path/to/file.ex "lib/**/*.{ex,exs,sface}" "test/**/*.{ex,exs}"
  ```
  """

  use Mix.Task

  alias Surface.Compiler.Converter
  alias Surface.Compiler.Converter_0_8

  @converter Converter_0_8

  defp format_string(string, converter) do
    Converter.convert(string, converter: converter)
  end

  #
  # Functions unique to surface.convert (Everything else is taken from Mix.Tasks.Format)
  #

  @doc false
  def convert_file_contents!(:stdin, input, converter) do
    # determine whether the input is Elixir or Surface code by checking if `Code.string_to_quoted` can parse it
    case Code.string_to_quoted(input) do
      {:ok, _} ->
        convert_ex_string!(input, converter)

      {:error, _} ->
        format_string(input, converter)
    end
  end

  def convert_file_contents!(file, input, converter) do
    ext = Path.extname(file)

    content =
      case ext do
        ".sface" ->
          format_string(input, converter)

        _ ->
          convert_ex_string!(input, converter)
      end

    converter.after_convert_file(ext, content)
  end

  defp convert_ex_string!(input, converter) do
    [
      {~r/( *)~F"\""(.*?)"""(\s)/s,
       fn _match, indent, code, space_after ->
         "#{indent}~F\"\"\"#{format_string(code, converter)}\"\"\"#{space_after}"
       end},
      {~r/~F\"([^\"].*?)\"/s, fn _match, code -> "~F\"#{format_string(code, converter)}\"" end},
      {~r/~F\[(.*?)\]/s, fn _match, code -> "~F[#{format_string(code, converter)}]" end},
      {~r/~F\((.*?)\)/s, fn _match, code -> "~F(#{format_string(code, converter)})" end},
      {~r/~F\{(.*?)\}/s, fn _match, code -> "~F{#{format_string(code, converter)}}" end}
    ]
    |> Enum.reduce(input, fn {regex, replacement}, code ->
      Regex.replace(regex, code, replacement)
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
    {dot_formatter, formatter_opts} = eval_dot_formatter(opts)

    args
    |> expand_args(dot_formatter, formatter_opts)
    |> Task.async_stream(&convert_file(&1, opts, @converter), ordered: false, timeout: 30000)
    |> Enum.reduce([], &collect_status/2)
    |> check!()
  end

  defp read_file(:stdin) do
    {IO.stream(:stdio, :line) |> Enum.to_list() |> IO.iodata_to_binary(), :stdin}
  end

  defp read_file(file) do
    {File.read!(file), file}
  end

  defp convert_file({file, _formatter_opts}, task_opts, converter) do
    {input, file} = read_file(file)
    formatted = convert_file_contents!(file, input, converter)
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

  defp expand_args([], dot_formatter, formatter_opts) do
    if no_entries_in_formatter_opts?(formatter_opts) do
      Mix.raise(
        "Expected one or more files/patterns to be given to mix format " <>
          "or for a .formatter.exs file to exist with an :inputs, :surface_inputs or :subdirectories key"
      )
    end

    dot_formatter
    |> expand_dot_inputs(formatter_opts)
    |> Enum.map(fn {file, {_dot_formatter, formatter_opts}} -> {file, formatter_opts} end)
  end

  defp expand_args(files_and_patterns, _dot_formatter, formatter_opts) do
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
      {file, formatter_opts}
    end
  end

  defp expand_dot_inputs(dot_formatter, formatter_opts) do
    if no_entries_in_formatter_opts?(formatter_opts) do
      Mix.raise("Expected :inputs or :surface_inputs key in #{dot_formatter}")
    end

    for input <- List.wrap(formatter_opts[:surface_inputs] || formatter_opts[:inputs]),
        file <- Path.wildcard(Path.join([input]), match_dot: true),
        do: {expand_relative_to_cwd(file), {dot_formatter, formatter_opts}},
        into: %{}
  end

  defp expand_relative_to_cwd(path) do
    case File.cwd() do
      {:ok, cwd} -> Path.expand(path, cwd)
      _ -> path
    end
  end

  defp stdin_or_wildcard("-"), do: [:stdin]
  defp stdin_or_wildcard(path), do: path |> Path.expand() |> Path.wildcard(match_dot: true)

  defp no_entries_in_formatter_opts?(formatter_opts) do
    is_nil(formatter_opts[:inputs]) and is_nil(formatter_opts[:surface_inputs])
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
    Mix.shell().error("mix surface.convert failed for stdin")
    reraise exception, stacktrace
  end

  defp check!([{:exit, file, exception, stacktrace} | _]) do
    Mix.shell().error("mix surface.convert failed for file: #{Path.relative_to_cwd(file)}")
    reraise exception, stacktrace
  end
end
