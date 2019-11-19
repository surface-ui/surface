defprotocol Surface.Translator.NodeTranslator do
  def translate(nodes, caller)
end

defimpl Surface.Translator.NodeTranslator, for: List do
  def translate(nodes, caller) do
    for node <- nodes do
      Surface.Translator.NodeTranslator.translate(node, caller)
    end
  end
end

defimpl Surface.Translator.NodeTranslator, for: [BitString, Integer] do
  def translate(node, _caller) do
    node
  end
end
