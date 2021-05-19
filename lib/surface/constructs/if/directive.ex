defmodule Surface.Constructs.If.Directive do
  use Surface.Directive,
    type: :boolean,
    name_pattern: "if"

  def process(_name, value, meta, node) do
    %AST.If{condition: value, children: [node], meta: meta}
  end
end
