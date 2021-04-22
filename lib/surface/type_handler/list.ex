defmodule Surface.TypeHandler.List do
  @moduledoc false

  use Surface.TypeHandler

  @impl true
  def literal_to_ast_node(_type, _name, _value, _meta) do
    :error
  end

  @impl true
  def expr_to_quoted(_type, attribute_name, [clause], [], _meta, _original) do
    {:ok, handle_list_expr(attribute_name, clause)}
  end

  @impl true
  def expr_to_quoted(_type, attribute_name, [], opts, _meta, _original) do
    {:ok, handle_list_expr(attribute_name, opts)}
  end

  def expr_to_quoted(_type, _attribute_name, _clauses, _opts, _meta, _original) do
    :error
  end

  defp handle_list_expr(_name, {:<-, _, [binding, value]}) do
    {binding, value}
  end

  defp handle_list_expr(_name, expr) when is_list(expr), do: expr

  defp handle_list_expr(name, expr) do
    quote generated: true do
      case unquote(expr) do
        value when is_list(value) ->
          value

        value ->
          raise "invalid value for property \"#{unquote(name)}\". Expected a :list, got: #{
                  inspect(value)
                }"
      end
    end
  end

  @impl true
  def update_prop_expr({_, value}, _meta) do
    value
  end

  def update_prop_expr(value, _meta) do
    value
  end
end
