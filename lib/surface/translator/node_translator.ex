defprotocol Surface.Translator.NodeTranslator do
  @fallback_to_any true
  def translate(nodes, caller)
end

defimpl Surface.Translator.NodeTranslator, for: List do
  def translate(nodes, caller) do
    for node <- nodes do
      Surface.Translator.NodeTranslator.translate(node, caller)
    end
  end
end

defimpl Surface.Translator.NodeTranslator, for: Any do
  def translate(node, _caller) do
    node
  end
end
