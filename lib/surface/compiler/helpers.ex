defmodule Surface.Compiler.Helpers do
  alias Surface.AST
  alias Surface.Compiler.CompileMeta
  alias Surface.IOHelper

  @builtin_common_assigns [
    :socket,
    :flash,
    :__context__,
    :__surface__
  ]

  @builtin_component_assigns [:inner_block] ++ @builtin_common_assigns

  @builtin_live_component_assigns [:id, :myself] ++ @builtin_component_assigns

  @builtin_live_view_assigns [:id, :session, :live_action, :uploads] ++ @builtin_common_assigns

  @builtin_assigns_by_type %{
    Surface.Component => @builtin_component_assigns,
    Surface.LiveComponent => @builtin_live_component_assigns,
    Surface.LiveView => @builtin_live_view_assigns
  }

  def builtin_assigns_by_type(type) do
    @builtin_assigns_by_type[type]
  end

  def interpolation_to_quoted!(text, meta) do
    case Code.string_to_quoted(text, file: meta.file, line: meta.line) do
      {:ok, expr} ->
        expr

      {:error, {position, error, token}} ->
        IOHelper.syntax_error(error <> token, meta.file, position_to_line(position))

      {:error, message} ->
        IOHelper.compile_error(message, meta.file, meta.line)
    end
  end

  def perform_assigns_checks(expr, meta) do
    used_assigns = used_assigns(expr)

    if meta.checks[:no_undefined_assigns] do
      caller = meta.caller
      component_type = Module.get_attribute(caller.module, :component_type)

      validate_no_undefined_assigns(used_assigns, caller, component_type)
    end
  end

  defp validate_no_undefined_assigns(
         used_assigns,
         %{function: {:render, _}} = caller,
         component_type
       )
       when component_type in [Surface.Component, Surface.LiveComponent] do
    defined_assigns = Keyword.keys(Surface.API.get_assigns(caller.module))
    builtin_assigns = builtin_assigns_by_type(component_type)
    undefined_assigns = Keyword.drop(used_assigns, builtin_assigns ++ defined_assigns)

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

  defp validate_no_undefined_assigns(_used_assigns, _caller, _component_type), do: nil

  @spec used_assigns(Macro.t()) :: list(atom())
  def used_assigns(expr) do
    {_expr, assigns} =
      Macro.prewalk(expr, [], fn
        {:@, _meta, [{assign, meta, _}]} = expr, assigns -> {expr, [{assign, meta} | assigns]}
        expr, assigns -> {expr, assigns}
      end)

    assigns
  end

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

  # We don't expect this to fail as `mod_str` should have been
  # already validated at the parser level
  def actual_component_module!(mod_str, env) do
    {:ok, ast} = Code.string_to_quoted(mod_str)
    Macro.expand(ast, env)
  end

  def check_module_loaded(module, node_alias) do
    case Code.ensure_compiled(module) do
      {:module, mod} ->
        {:ok, mod}

      {:error, _reason} ->
        message = "module #{inspect(module)} could not be loaded"

        if !String.contains?(node_alias, ".") and inspect(module) == node_alias do
          {:error, message, hint_for_unloaded_module(node_alias)}
        else
          {:error, message}
        end
    end
  end

  def check_module_is_component(module) do
    if function_exported?(module, :component_type, 0) do
      {:ok, module}
    else
      {:error, "module #{inspect(module)} is not a component"}
    end
  end

  def validate_component_module(mod, node_alias) do
    with {:ok, _mod} <- check_module_loaded(mod, node_alias),
         {:ok, _mod} <- check_module_is_component(mod) do
      :ok
    end
  end

  def position_to_line(position) when is_list(position) do
    Keyword.fetch!(position, :line)
  end

  def position_to_line(line) do
    line
  end

  defp hint_for_unloaded_module(node_alias) do
    """
    Hint: Make sure module `#{node_alias}` can be successfully compiled.

    If the module is namespaced, you can use its full name. For instance:

      <MyProject.Components.#{node_alias}>

    or add a proper alias so you can use just `<#{node_alias}>`:

      alias MyProject.Components.#{node_alias}
    """
  end
end
