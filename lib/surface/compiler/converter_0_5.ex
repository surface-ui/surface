defmodule Surface.Compiler.Converter_0_5 do
  @moduledoc false

  @behaviour Surface.Compiler.Converter

  def convert(:interpolation, text, _opts) do
    String.slice(text, 1..-2)
  end

  def convert(:tag_name, "If", _opts) do
    "#if"
  end

  def convert(:attr_name, ":if", _opts) do
    "#if"
  end

  def convert(:tag_name, "For", _opts) do
    "#for"
  end

  def convert(:attr_name, ":for", _opts) do
    "#for"
  end

  def convert(_type, text, _opts) do
    text
  end
end
