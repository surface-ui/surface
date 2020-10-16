defmodule Surface.Compiler.Helpers do
  alias Surface.AST
  alias Surface.Compiler.CompileMeta
  alias Surface.IOHelper

  @builtin_assigns [:flash, :live_action, :live_module, :socket, :inner_block, :__context__, :__surface__]

  def interpolation_to_quoted!(text, meta) do
    case Code.string_to_quoted(text, file: meta.file, line: meta.line) do
      {:ok, expr} ->
        expr

      {:error, {line, error, token}} ->
        IOHelper.syntax_error(error <> token, meta.file, line)

      {:error, message} ->
        IOHelper.compile_error(message, meta.file, meta.line)
    end
  end

  def validate_assign_usage(expr, caller) do
    used_assigns = used_assigns(expr)
    defined_assigns = Surface.API.get_assigns(caller.module)

    undefined_assigns = Keyword.drop(used_assigns, @builtin_assigns ++ defined_assigns)

    available_assigns =
      Enum.map_join(defined_assigns, ", ", fn name -> "@" <> to_string(name) end)

    assign_message =
      if Enum.empty?(defined_assigns),
        do: "No assigns are defined in #{inspect(caller.module)}.",
        else: "Available assigns in #{inspect(caller.module)}: #{available_assigns}."

    for {assign, assign_meta} <- undefined_assigns do
      message = """
      undefined assign `@#{to_string(assign)}`.

      #{assign_message}

      Hint: You can define assigns using any of the available macros (`prop`, `data` and `slot`).

      For instance: `prop #{assign}, :any`
      """

      assign_line = assign_meta[:line] || caller.line

      IOHelper.warn(message, caller, fn _ -> assign_line end)
    end
  end

  @spec used_assigns(Macro.t()) :: list(atom())
  def used_assigns(atom) when is_atom(atom), do: []
  def used_assigns(number) when is_number(number), do: []
  def used_assigns(binary) when is_binary(binary), do: []
  def used_assigns({first, second}), do: used_assigns(first) ++ used_assigns(second)
  def used_assigns(list) when is_list(list), do: Enum.flat_map(list, &used_assigns/1)

  def used_assigns({:@, _at_meta, [{assign, meta, args}]}),
    do: [{assign, meta} | used_assigns(args)]

  def used_assigns({first, _meta, second}), do: used_assigns(first) ++ used_assigns(second)

  def to_meta(%{line: line} = tree_meta, %CompileMeta{
        line_offset: offset,
        file: file,
        caller: caller,
        checks: checks
      }) do
    AST.Meta
    |> Kernel.struct(tree_meta)
    # The rational here is that offset is the offset from the start of the file to the first line in the
    # surface expression.
    |> Map.put(:line, line + offset - 1)
    |> Map.put(:line_offset, offset)
    |> Map.put(:file, file)
    |> Map.put(:caller, caller)
    |> Map.put(:checks, checks)
  end

  def to_meta(%{line: line} = tree_meta, %AST.Meta{line_offset: offset} = parent_meta) do
    parent_meta
    |> Map.merge(tree_meta)
    |> Map.put(:line, line + offset - 1)
  end

  def did_you_mean(target, list) do
    Enum.reduce(list, {nil, 0}, &max_similar(&1, to_string(target), &2))
  end

  defp max_similar(source, target, {_, current} = best) do
    score = source |> to_string() |> String.jaro_distance(target)
    if score < current, do: best, else: {source, score}
  end

  def list_to_string(_singular, _plural, []) do
    ""
  end

  def list_to_string(singular, _plural, [item]) do
    "#{singular} #{inspect(item)}"
  end

  def list_to_string(_singular, plural, items) do
    [last | rest] = items |> Enum.map(&inspect/1) |> Enum.reverse()
    "#{plural} #{rest |> Enum.reverse() |> Enum.join(", ")} and #{last}"
  end

  @blanks ' \n\r\t\v\b\f\e\d\a'

  def blank?([]), do: true

  def blank?([h | t]), do: blank?(h) && blank?(t)

  def blank?(""), do: true

  def blank?(char) when char in @blanks, do: true

  def blank?(<<h, t::binary>>) when h in @blanks, do: blank?(t)

  def blank?(_), do: false

  def is_blank_or_empty(%AST.Literal{value: value}),
    do: blank?(value)

  def is_blank_or_empty(%AST.Template{children: children}),
    do: Enum.all?(children, &is_blank_or_empty/1)

  def is_blank_or_empty(_node), do: false

  def actual_module(mod_str, env) do
    {:ok, ast} = Code.string_to_quoted(mod_str)

    case Macro.expand(ast, env) do
      mod when is_atom(mod) ->
        {:ok, mod}

      _ ->
        {:error, "#{mod_str} is not a valid module name"}
    end
  end

  def check_module_loaded(module, mod_str) do
    case Code.ensure_compiled(module) do
      {:module, mod} ->
        {:ok, mod}

      {:error, _reason} ->
        {:error, "module #{mod_str} could not be loaded"}
    end
  end

  def check_module_is_component(module, mod_str) do
    if function_exported?(module, :component_type, 0) do
      {:ok, module}
    else
      {:error, "module #{mod_str} is not a component"}
    end
  end

  def module_name(name, caller) do
    with {:ok, mod} <- actual_module(name, caller),
         {:ok, mod} <- check_module_loaded(mod, name) do
      check_module_is_component(mod, name)
    end
  end
end
