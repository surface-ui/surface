defmodule Surface.TypeHandler.Style do
  @moduledoc false

  use Surface.TypeHandler

  @impl true
  def expr_to_value([value], []) when is_binary(value) do
    styles =
      for style <- String.split(value, ~r/;/, trim: true) do
        [k, v] = String.split(style, ":", trim: true, parts: 2)
        {String.trim(k) |> String.to_atom(), String.trim(v)}
      end

    {:ok, styles}
  end

  def expr_to_value([value], []) do
    if is_list(value) and Keyword.keyword?(value) do
      {:ok, value}
    else
      {:error, value}
    end
  end

  def expr_to_value([], opts) do
    {:ok, opts}
  end

  def expr_to_value(clauses, opts) do
    {:error, clauses ++ opts}
  end

  @impl true
  def value_to_html(_name, value) do
    {:ok, value |> Enum.map_join("; ", fn {k, v} -> "#{k}: #{v}" end)}
  end
end
