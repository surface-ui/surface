defmodule Surface.TypeHandler.Default do
  @moduledoc false

  use Surface.TypeHandler

  alias Surface.IOHelper

  @impl true
  def expr_to_value([value], []) do
    {:ok, value}
  end

  def expr_to_value(clauses, opts) do
    {:error, clauses ++ opts}
  end

  @impl true
  def value_to_html(name, value) do
    if String.Chars.impl_for(value) do
      value
    else
      IOHelper.runtime_error(
        "invalid value for attribute \"#{name}\". Expected a type that implements " <>
          "the String.Chars protocol (e.g. string, boolean, integer, atom, ...), " <>
          "got: #{inspect(value)}"
      )
    end
  end

  @impl true
  def update_prop_expr(value, _meta) do
    value
  end
end
