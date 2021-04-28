defmodule Surface.Compiler.Converter_0_4 do
  @moduledoc false

  @behaviour Surface.Compiler.Converter

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

  def convert(:unquoted_string, value, _opts) do
    "{{#{value}}}"
  end

  def convert(_type, text, _opts) do
    text
  end
end
