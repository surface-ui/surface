defmodule Surface.Components.Raw do
  @moduledoc """
  A macro component that does not translate any of its contents.

  The content will be passed untouched to the underlying Phoenix's
  template engine.

  > **Note**: By skipping translation, all Surface specific features
  are automatically disabled, including code interpolation with `{{...}}`,
  syntactic sugar for attributes and markup validation.
  """

  use Surface.MacroComponent

  alias Surface.IOHelper

  @doc "The content that will not be translated by Surface"
  slot default

  def expand(_attributes, children, meta) do
    message = """
    using <#Raw> has been deprecated and will be removed in future versions.

    Hint: replace `<#Raw>` with `<#raw>`
    """

    IOHelper.warn(message, meta.caller, fn _ -> meta.line end)

    %Surface.AST.Literal{
      value: List.to_string(children)
    }
  end
end
