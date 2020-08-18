defmodule Surface.TypeHandler.List do
  @moduledoc false

  use Surface.TypeHandler

  @impl true
  def validate_expr([_clause], [], _module) do
    :ok
  end

  def validate_expr(_clauses, _opts, _module) do
    :error
  end

  @impl true
  def expr_to_quoted(_type, attribute_name, [clause], _opts, _module, _original) do
    handle_list_expr(attribute_name, clause)
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
end
