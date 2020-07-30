defmodule Surface.Directive.Show do
  @behaviour Surface.Directive

  def extract({":show", {:attribute_expr, [value], expr_meta}, attr_meta}, meta) do
    %Surface.AST.Directive{
      module: __MODULE__,
      name: :show,
      value: directive_value(value, Map.merge(meta, expr_meta)),
      meta: Map.merge(meta, attr_meta)
    }
  end

  def extract({":show", value, attr_meta}, meta) do
    %Surface.AST.Directive{
      module: __MODULE__,
      name: :show,
      value: %Surface.AST.Text{value: to_string(value)},
      meta: Map.merge(meta, attr_meta)
    }
  end

  def extract(_, _), do: []

  def process(node), do: node

  defp directive_value(value, meta) do
    {:identity, _, value} =
      Code.string_to_quoted!("identity(#{value})", line: meta.line, file: meta.file)

    if Enum.count(value) == 1 do
      Enum.at(value, 0)
    else
      value
    end
  end
end
