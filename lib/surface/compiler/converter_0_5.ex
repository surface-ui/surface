defmodule Surface.Compiler.Converter_0_5 do
  @moduledoc false

  @behaviour Surface.Compiler.Converter

  def convert(:interpolation, text, _state, _opts) do
    if String.starts_with?(text, "{") and String.ends_with?(text, "}") do
      String.slice(text, 1..-2)
    else
      text
    end
  end

  def convert(:unquoted_string, value, _state, _opts) do
    "{#{value}}"
  end

  def convert(:double_quoted_string, value, _state, _opts) do
    new_value = Regex.replace(~r/{{(.+?)}}/, value, "\#{\\1}")

    if new_value != value do
      "{#{new_value}}"
    else
      value
    end
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

  def convert(:tag_name, "#Raw", _state, _opts) do
    "#raw"
  end

  ## Planned changes. Uncomment as the related implementation gets merged

  # def convert(:tag_name, "For", _state, _opts) do
  #   "#for"
  # end

  # def convert(:attr_name, ":props", %{tag_name: "#slot"}, _opts) do
  #   "args"
  # end

  def convert(_type, text, _state, _opts) do
    text
  end
end
