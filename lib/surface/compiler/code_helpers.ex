defmodule Surface.Compiler.Helpers do
  alias Surface.AST
  alias Surface.Compiler.CompileMeta
  alias Surface.IOHelper

  def interpolation_to_quoted!(text, meta) do
    with {:ok, expr} <- Code.string_to_quoted(text, file: meta.file, line: meta.line),
         :ok <- validate_interpolation(expr, meta) do
      expr
    else
      {:error, {line, error, token}} ->
        IOHelper.syntax_error(error <> token, meta.file, line)

      {:error, message} ->
        IOHelper.compile_error(message, meta.file, meta.line - 1)

      _ ->
        IOHelper.syntax_error(
          "invalid interpolation '#{text}'",
          meta.file,
          meta.line
        )
    end
  end

  def attribute_expr_to_quoted!(value, :css_class, meta) do
    with {:ok, expr} <-
           Code.string_to_quoted("Surface.css_class(#{value})", line: meta.line, file: meta.file),
         :ok <- validate_attribute_expression(expr, :css_class, meta) do
      expr
    else
      {:error, {line, error, token}} ->
        IOHelper.syntax_error(
          error <> token,
          meta.file,
          line
        )

      # Once we do validation
      # {:error, message} ->
      #   IOHelper.syntax_error(
      #     "invalid css class expression '#{value}' (#{message})",
      #     meta.file,
      #     meta.line
      #   )

      _ ->
        IOHelper.syntax_error(
          "invalid css class expression '#{value}'",
          meta.file,
          meta.line
        )
    end
  end

  def attribute_expr_to_quoted!(value, type, meta) when type in [:keyword, :list, :map, :event] do
    with {:ok, {:identity, _, expr}} <-
           Code.string_to_quoted("identity(#{value})", line: meta.line, file: meta.file),
         :ok <- validate_attribute_expression(expr, type, meta) do
      if Enum.count(expr) == 1 do
        Enum.at(expr, 0)
      else
        expr
      end
    else
      {:error, {line, error, token}} ->
        IOHelper.syntax_error(
          error <> token,
          meta.file,
          line
        )

      # Once we do validation
      # {:error, message} ->
      #   IOHelper.syntax_error(
      #     "invalid #{to_string(type)} expression '#{value}' (#{message})",
      #     meta.file,
      #     meta.line
      #   )

      _ ->
        IOHelper.syntax_error(
          "invalid #{to_string(type)} expression '#{value}'",
          meta.file,
          meta.line
        )
    end
  end

  def attribute_expr_to_quoted!(value, :generator, meta) do
    with {:ok, {:for, _, expr}} when is_list(expr) <-
           Code.string_to_quoted("for #{value}", line: meta.line, file: meta.file),
         :ok <- validate_attribute_expression(expr, :generator, meta) do
      expr
    else
      {:error, {line, error, token}} ->
        IOHelper.syntax_error(
          error <> token,
          meta.file,
          line
        )

      # Once we do validation
      # {:error, message} ->
      #   IOHelper.syntax_error(
      #     "invalid generator expression '#{value}' (#{message})",
      #     meta.file,
      #     meta.line
      #   )

      _ ->
        IOHelper.syntax_error(
          "invalid generator expression '#{value}'",
          meta.file,
          meta.line
        )
    end
  end

  def attribute_expr_to_quoted!(value, _type, meta) do
    case Code.string_to_quoted(value, line: meta.line, file: meta.file) do
      {:ok, expr} ->
        expr

      {:error, {line, error, token}} ->
        IOHelper.syntax_error(
          error <> token,
          meta.file,
          line
        )
    end
  end

  defp validate_attribute_expression(_expr, _, _meta) do
    # TODO: Add any validation here
    :ok
  end

  defp validate_interpolation({:@, _, [{:inner_content, _, args}]}, _meta) when is_list(args) do
    {:error,
     """
     the `inner_content` anonymous function should be called using \
     the dot-notation. Use `inner_content.([])` instead of `inner_content([])`\
     """}
  end

  defp validate_interpolation({{:., _, dotted_args} = expr, metadata, args}, meta) do
    if List.last(dotted_args) == :inner_content and !Keyword.get(metadata, :no_parens, false) do
      {:error,
       """
       the `inner_content` anonymous function should be called using \
       the dot-notation. Use `inner_content.([])` instead of `inner_content([])`\
       """}
    else
      [expr | args]
      |> Enum.map(fn arg -> validate_interpolation(arg, meta) end)
      |> Enum.find(:ok, &match?({:error, _}, &1))
    end
  end

  defp validate_interpolation({func, _, args}, meta) when is_atom(func) and is_list(args) do
    args
    |> Enum.map(fn arg -> validate_interpolation(arg, meta) end)
    |> Enum.find(:ok, &match?({:error, _}, &1))
  end

  defp validate_interpolation({func, _, args}, _meta) when is_atom(func) and is_atom(args),
    do: :ok

  defp validate_interpolation({func, _, args}, meta) when is_tuple(func) and is_list(args) do
    [func | args]
    |> Enum.map(fn arg -> validate_interpolation(arg, meta) end)
    |> Enum.find(:ok, &match?({:error, _}, &1))
  end

  defp validate_interpolation({func, _, args}, meta) when is_tuple(func) and is_atom(args) do
    validate_interpolation(func, meta)
  end

  defp validate_interpolation(expr, meta) when is_tuple(expr) do
    expr
    |> Tuple.to_list()
    |> Enum.map(fn arg -> validate_interpolation(arg, meta) end)
    |> Enum.find(:ok, &match?({:error, _}, &1))
  end

  defp validate_interpolation(expr, meta) when is_list(expr) do
    expr
    |> Enum.map(fn arg -> validate_interpolation(arg, meta) end)
    |> Enum.find(:ok, &match?({:error, _}, &1))
  end

  defp validate_interpolation(_expr, _meta), do: :ok

  def to_meta(%{line: line} = tree_meta, %CompileMeta{
        line_offset: offset,
        file: file,
        caller: caller
      }) do
    AST.Meta
    |> Kernel.struct(tree_meta)
    |> Map.put(:line, line + offset)
    |> Map.put(:line_offset, offset)
    |> Map.put(:file, file)
    |> Map.put(:caller, caller)
  end

  def to_meta(%{line: line} = tree_meta, %AST.Meta{line_offset: offset} = parent_meta) do
    parent_meta
    |> Map.merge(tree_meta)
    |> Map.put(:line, line + offset)
  end
end
