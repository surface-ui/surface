defmodule Surface.Compiler.Converter_0_5 do
  @moduledoc false

  @behaviour Surface.Compiler.Converter

  def convert(:interpolation, text, _state, _opts) do
    String.slice(text, 1..-2)
  end

  # TODO: should we also handle "slot" or shoud we force running Converter_0_4 before?
  def convert(:attr_name, ":props", %{tag_name: "#slot"}, _opts) do
    "args"
  end

  def convert(_type, text, _state, _opts) do
    text
  end
end
