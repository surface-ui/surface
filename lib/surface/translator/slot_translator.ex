defmodule Surface.Translator.SlotTranslator do
  @moduledoc false

  alias Surface.Translator
  alias Surface.Translator.ComponentTranslator

  @behaviour Translator

  @impl true
  def translate(node, caller) do
    ComponentTranslator.translate(node, caller)
  end
end
