defmodule Surface.EEx.Engine do
  @behaviour EEx.Engine

  def init(_opts) do
    []
  end

  def handle_begin(state) do
    IO.puts("begin: #{inspect(state)}")
    []
  end

  def handle_body(state) do
    IO.puts("body: #{inspect(state)}")
    state
  end

  def handle_end(state) do
    IO.puts("end: #{inspect(state)}")
    state
  end

  def handle_expr(state, marker, expr) do
    IO.puts("expr: (#{inspect(state)}, #{marker}, #{inspect(expr)})")
    [expr | state]
  end

  def handle_text(state, text) do
    IO.puts("text: #{inspect(state)}, #{text}")
    [text | state]
  end
end
