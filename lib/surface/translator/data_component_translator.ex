defmodule Surface.Translator.DataComponentTranslator do

  alias Surface.Translator
  alias Surface.Translator.ComponentTranslator

  @behaviour Translator

  def translate(node, caller) do
    ComponentTranslator.translate(node, caller)
  end
end

