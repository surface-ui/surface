defmodule Surface.Compiler.Converter_0_5 do
  @moduledoc false

  @behaviour Surface.Compiler.Converter

  def convert(:interpolation, text, _state, _opts) do
    String.slice(text, 1..-2)
  end

  def convert(:unquoted_string, value, _state, _opts) do
    "{#{value}}"
  end

  def convert(:tag_name, "template", _state, _opts) do
    "#template"
  end

  def convert(:tag_name, "slot", _state, _opts) do
    "#slot"
  end

  def convert(:tag_name, "If", _state, _opts) do
    "#if"
  end

  def convert(:tag_name, "For", _state, _opts) do
    "#for"
  end

  def convert(:attr_name, ":props", %{tag_name: "#slot"}, _opts) do
    "args"
  end

  def convert(_type, text, _state, _opts) do
    text
  end
end
