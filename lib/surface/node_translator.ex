defprotocol Surface.NodeTranslator do
  @fallback_to_any true
  def translate(nodes, caller)
end

defimpl Surface.NodeTranslator, for: List do
  def translate(nodes, caller) do
    for node <- nodes do
      Surface.NodeTranslator.translate(node, caller)
    end
  end
end

defimpl Surface.NodeTranslator, for: Any do
  def translate(node, _caller) do
    node
  end
end
