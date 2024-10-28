defmodule Surface.Compiler.Helpers do
  @moduledoc false
  alias Surface.AST
  alias Surface.Compiler.CompileMeta
  alias Surface.IOHelper

  @builtin_common_assigns [
    :__context__,
    :__caller_scope_id__,
    :streams
  ]

  @builtin_component_assigns [:inner_block] ++ @builtin_common_assigns

  @builtin_live_component_assigns [:id, :socket, :myself] ++ @builtin_component_assigns

  @builtin_live_view_assigns [:id, :socket, :session, :live_action, :uploads, :flash] ++
                               @builtin_common_assigns

  @builtin_assigns_by_type %{
    Surface.Component => @builtin_component_assigns,
    Surface.LiveComponent => @builtin_live_component_assigns,
    Surface.LiveView => @builtin_live_view_assigns
  }

  @env Mix.env()

  def builtin_assigns_by_type(type) do
    @builtin_assigns_by_type[type]
  end

  def expression_to_quoted!(text, meta) do
    case Code.string_to_quoted(text, file: meta.file, line: meta.line, column: meta.column) do
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
    defined_assigns =
      caller.module
      |> Surface.API.get_assigns()
      |> Enum.map(&(&1[:opts][:as] || &1.name))

    builtin_assigns = builtin_assigns_by_type(component_type)
    undefined_assigns = Keyword.drop(used_assigns, builtin_assigns ++ defined_assigns)

    available_assigns = Enum.map_join(defined_assigns, ", ", fn name -> "@" <> to_string(name) end)

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
      assign_file = assign_meta[:file] || caller.file

      IOHelper.warn(message, caller, assign_file, assign_line)
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

  def to_meta(tree_meta, %CompileMeta{caller: caller, checks: checks, style: style, caller_spec: caller_spec}) do
    %AST.Meta{
      line: tree_meta.line,
      column: tree_meta.column,
      file: tree_meta.file,
      caller: caller,
      checks: checks,
      style: style,
      caller_spec: caller_spec
    }
  end

  def to_meta(tree_meta, %AST.Meta{} = parent_meta) do
    %{parent_meta | line: tree_meta.line, column: tree_meta.column}
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

  def list_to_string(singular, plural, items, map_fun \\ &inspect/1)

  def list_to_string(singular, _plural, [item], map_fun) do
    "#{singular} #{map_fun.(item)}"
  end

  def list_to_string(_singular, plural, items, map_fun) do
    [last | rest] = items |> Enum.map(map_fun) |> Enum.reverse()
    "#{plural} #{rest |> Enum.reverse() |> Enum.join(", ")} and #{last}"
  end

  @blanks ~c" \n\r\t\v\b\f\e\d\a"

  def blank?([]), do: true

  def blank?([h | t]), do: blank?(h) && blank?(t)

  def blank?(""), do: true

  def blank?(char) when char in @blanks, do: true

  def blank?(<<h, t::binary>>) when h in @blanks, do: blank?(t)

  def blank?(_), do: false

  def is_blank_or_empty(%AST.Literal{value: value}),
    do: blank?(value)

  def is_blank_or_empty(%AST.SlotEntry{children: children}),
    do: Enum.all?(children, &is_blank_or_empty/1)

  def is_blank_or_empty(_node), do: false

  # We don't expect this to fail as `mod_str` should have been
  # already validated at the parser level
  def actual_component_module!(mod_str, env) do
    {:ok, ast} = Code.string_to_quoted(mod_str)
    Macro.expand(ast, env)
  end

  def decompose_component_tag("." <> fun_name, env) do
    fun = String.to_atom(fun_name)

    module =
      cond do
        Module.defines?(env.module, {fun, 1}) ->
          env.module

        mod = get_imported_module({fun, 1}, env) ->
          mod

        true ->
          env.module
      end

    {:local, module, fun}
  end

  def decompose_component_tag(tag_name, env) do
    case String.split(tag_name, ".") |> Enum.reverse() do
      [<<first, _::binary>> = fun_name | rest] when first in ?a..?z ->
        aliases = rest |> Enum.reverse() |> Enum.map(&String.to_atom/1)
        fun = String.to_atom(fun_name)
        {:remote, Macro.expand({:__aliases__, [], aliases}, env), fun}

      _ ->
        {:ok, ast} = Code.string_to_quoted(tag_name)
        mod = Macro.expand(ast, env)

        if mod == env.module do
          {:recursive_component, mod, nil}
        else
          {:component, mod, nil}
        end
    end
  end

  # TODO: remove this function and use the `caller_spec` field on the `CompileMeta` struct instead
  def get_module_attribute(module, key, default) do
    if @env == :test do
      # If the template is compiled directly in a test module, get_attribute might fail,
      # breaking some of the tests once in a while.
      try do
        Module.get_attribute(module, key, default)
      rescue
        _e in ArgumentError -> default
      end
    else
      Module.get_attribute(module, key, default)
    end
  end

  def is_stateful_component(module) do
    cond do
      function_exported?(module, :component_type, 0) ->
        module.component_type() == Surface.LiveComponent

      Module.open?(module) ->
        get_module_attribute(module, :component_type, false) == Surface.LiveComponent

      true ->
        false
    end
  end

  defp get_imported_module(func, env) do
    Enum.find_value(env.functions, fn {mod, funcs} ->
      if mod not in [Application, IEx.Helpers, Kernel, Kernel.Typespec] do
        Enum.find_value(funcs, fn
          ^func -> mod
          _ -> nil
        end)
      end
    end)
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
    make sure module `#{node_alias}` can be successfully compiled.

    If the module is namespaced, you can use its full name. For instance:

      <MyProject.Components.#{node_alias}>

    or add a proper alias so you can use just `<#{node_alias}>`:

      alias MyProject.Components.#{node_alias}
    """
  end
end
