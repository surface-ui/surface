defmodule Surface.Translator.ComponentTranslator do
  @moduledoc false

  alias Surface.Translator

  @behaviour Translator

  @impl true
  def translate(node, caller) do
    Surface.Translator.LiveComponentTranslator.translate(node, caller)
  end
end
