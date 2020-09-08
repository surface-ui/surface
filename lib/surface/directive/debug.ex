defmodule Surface.Directive.Debug do
  use Surface.Directive,
    extract: [
      name: ":debug",
      type: :static_list
    ]

  def handle_value(%AST.Text{value: true}, _meta) do
    {:ok,
     %AST.AttributeExpr{
       original: "",
       value: [:code],
       meta: meta
     }}
  end

  def handle_value(%AST.AttributeExpr{value: expr} = value, meta) do
    if Enum.any?(expr, &(not is_atom(&1))) do
      {:error,
       """
       invalid value for directive :debug. Expected a list of atoms, \
       got: #{String.trim(value)}.\
       """}
    else
      {:ok, value}
    end
  end

  def process(%AST.Directive{value: %AST.AttributeExpr{value: debug}}, %type{} = node) do
    node = %{node | debug: Keyword.merge(node.debug || [], debug)}

    if Enum.member?(node.debug, :ast) do
      IO.puts(">>> DEBUG(AST): #{node.meta.file}:#{node.meta.line}")
      IO.puts(inspect(node, pretty: true))
      IO.puts("<<<")
    end

    if type in [AST.VoidTag, AST.Tag, AST.Container] and Enum.member?(node.debug, :code) do
      %AST.If{
        condition: %AST.AttributeExpr{
          original: "generated from :debug",
          value: true,
          meta: node.meta
        },
        debug: node.debug,
        meta: node.meta,
        children: [node]
      }
    else
      node
    end
  end
end
