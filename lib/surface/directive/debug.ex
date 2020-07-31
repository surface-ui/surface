defmodule Surface.Directive.Debug do
  use Surface.Directive

  def extract({":debug", _, attr_meta}, meta) do
    %AST.Directive{
      module: __MODULE__,
      name: :debug,
      value: nil,
      meta: Helpers.to_meta(attr_meta, meta)
    }
  end

  def extract(_, _), do: []

  def process(_, node) do
    IO.puts(">>> DEBUG: #{node.meta.file}:#{node.meta.line}")
    IO.puts(inspect(node, pretty: true))
    IO.puts("<<<")

    node
  end
end
