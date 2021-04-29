defmodule Surface.Compiler.Converter_0_4 do
  @moduledoc false

  @behaviour Surface.Compiler.Converter

  def convert(:tag_name, "template", _state, _opts) do
    "#template"
  end

  def convert(:tag_name, "slot", _state, _opts) do
    "#slot"
  end

  def convert(:tag_name, "If", _state, _opts) do
    "#if"
  end

  def convert(:attr_name, ":if", _state, _opts) do
    "#if"
  end

  def convert(:tag_name, "For", _state, _opts) do
    "#for"
  end

  def convert(:attr_name, ":for", _state, _opts) do
    "#for"
  end

  def convert(:unquoted_string, value, _state, _opts) do
    "{{#{value}}}"
  end

  def convert(_type, text, _state, _opts) do
    text
  end
end
