defmodule Surface.Components.Raw do
  @moduledoc """
  A macro component that does not translate any of its contents.

  You can use this component when you want to skip translation
  and write regular Phoenix templates code directly or when you
  don't want your HTML to be translated at all.

  > **Note**: By skipping translation, all Surface specific features
  are automatically disabled, including code interpolation with `{{...}}`,
  syntactic sugar for attributes and markup validation.
  """

  use Surface.MacroComponent

  @doc false
  def translate({_, _, children, _}, _caller) do
    {[], children, []}
  end
end
