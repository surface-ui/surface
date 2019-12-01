defmodule Surface.Translator.DataComponentTranslator do

  alias Surface.Translator.ComponentTranslator

  def translate(node, caller) do
    ComponentTranslator.translate(node, caller)
  end
end

