defmodule Surface.Compiler.Converter_0_5 do
  @moduledoc false

  @behaviour Surface.Compiler.Converter

  @impl true
  def opts() do
    [handle_full_node: ["If", "For"]]
  end

  @impl true
  def convert(:expr, text, _state, _opts) do
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
    new_value = Regex.replace(~r/{{(.+?)}}/s, value, "\#{\\1}")

    if new_value != value do
      "{#{new_value}}"
    else
      value
    end
  end

  def convert(:tag_open_begin, "<If", _state, _opts) do
    "{#if"
  end

  def convert(:tag_open_end, text, %{tag_open_begin: "<If"}, _opts) do
    [_, condition] = Regex.run(~r/condition={{(.+)}}/s, text)
    " #{String.trim(condition)}}"
  end

  def convert(:tag_close, "</If>", _state, _opts) do
    "{/if}"
  end

  def convert(:tag_open_begin, "<For", _state, _opts) do
    "{#for"
  end

  def convert(:tag_open_end, text, %{tag_open_begin: "<For"}, _opts) do
    [_, each] = Regex.run(~r/each={{(.+)}}/s, text)
    " #{String.trim(each)}}"
  end

  def convert(:tag_close, "</For>", _state, _opts) do
    "{/for}"
  end

  def convert(:tag_name, "template", _state, _opts) do
    "#template"
  end

  def convert(:tag_name, "slot", _state, _opts) do
    "#slot"
  end

  ## Planned changes. Uncomment as the related implementation gets merged

  # def convert(:attr_name, ":props", %{tag_name: "#slot"}, _opts) do
  #   "args"
  # end

  def convert(_type, text, _state, _opts) do
    text
  end
end
