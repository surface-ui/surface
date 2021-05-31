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
      text
      |> String.slice(1..-2)
      |> trim_one()
    else
      text
    end
  end

  def convert(:unquoted_string, value, _state, _opts) do
    "{#{value}}"
  end

  def convert(:double_quoted_string, value, _state, _opts) do
    new_value = Regex.replace(~r/{{(.+?)}}/s, value, fn _, x -> "\#{#{trim_one(x)}}" end)

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

  defp trim_one(text) do
    text
    |> String.replace_prefix(" ", "")
    |> String.replace_suffix(" ", "")
  end
end
