defmodule Surface.TypeHandler.List do
  @moduledoc false

  use Surface.TypeHandler

  @impl true
  def literal_to_ast_node(_type, _name, _value, _meta) do
    :error
  end

  @impl true
  def expr_to_quoted(_type, attribute_name, [clause], [], meta, _original) do
    {:ok, handle_list_expr(attribute_name, clause, meta.module)}
  end

  @impl true
  def expr_to_quoted(_type, attribute_name, [], opts, meta, _original) do
    {:ok, handle_list_expr(attribute_name, opts, meta.module)}
  end

  def expr_to_quoted(_type, _attribute_name, _clauses, _opts, _meta, _original) do
    :error
  end

  defp handle_list_expr(_name, expr, _module) when is_list(expr), do: expr

  defp handle_list_expr(name, expr, module) do
    name = name || Enum.find(module.__props__(), & &1.opts[:root]).name

    quote generated: true do
      case unquote(expr) do
        value when is_list(value) or is_struct(value, Range) ->
          Enum.to_list(value)

        value ->
          raise "invalid value for property \"#{unquote(name)}\". Expected a :list, got: #{inspect(value)}"
      end
    end
  end
end
