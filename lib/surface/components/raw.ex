defmodule Surface.Components.Raw do
  @moduledoc """
  A macro component that does not translate any of its contents.

  The content will be passed untouched to the underlying Phoenix's
  template engine.

  > **Note**: By skipping translation, all Surface specific features
  are automatically disabled, including code interpolation with `{...}`,
  syntactic sugar for attributes and markup validation.
  """

  use Surface.MacroComponent

  @doc "The content that will not be translated by Surface"
  slot default

  def expand(_attributes, content, _meta) do
    %Surface.AST.Literal{value: content}
  end
end
