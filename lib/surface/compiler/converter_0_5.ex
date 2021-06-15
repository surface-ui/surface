defmodule Surface.Compiler.Converter_0_5 do
  @moduledoc false

  @behaviour Surface.Compiler.Converter

  @impl true
  def opts() do
    [handle_full_node: ["If", "For"]]
  end

  @impl true
  def after_convert_file(ext, content) when ext in [".ex", ".exs"] do
    content = Regex.replace(~r/~H("""|\"|\[|\(|\{)/s, content, "~F\\1")
    Regex.replace(~r/^(\s*slot[\s|\(].+?,\s*)props:(.+)/m, content, "\\1args:\\2")
  end

  def after_convert_file(_ext, content) do
    content
  end

  @impl true
  def convert(:expr, text, _state, _opts) do
    if String.starts_with?(text, "{") and String.ends_with?(text, "}") do
      case Regex.run(~r/^{\s*#\s*(.*?)\s*}$/, text) do
        [_, comment] -> "!-- #{comment} --"
        _ -> text |> String.slice(1..-2) |> maybe_trim_one()
      end
    else
      text
    end
  end

  def convert(:unquoted_string, value, _state, _opts) do
    "{#{value}}"
  end

  def convert(:double_quoted_string, value, _state, _opts) do
    new_value = Regex.replace(~r/{{(.+?)}}/s, value, fn _, x -> "\#{#{maybe_trim_one(x)}}" end)

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

  def convert(:attr_name, ":props", %{tag_name: "slot"}, _opts) do
    ":args"
  end

  def convert(:attr_name, "phx_feedback_for", %{tag_name: "ErrorTag"}, _opts) do
    "feedback_for"
  end

  def convert(_type, text, _state, _opts) do
    text
  end

  defp maybe_trim_one(original_text) do
    text = String.replace_prefix(original_text, " ", "")

    # don't remove the last space if the closing `}` is at a new line
    # containing only spaces (indentation)
    if Regex.match?(~r/\n\s*$/, text) do
      text
    else
      String.replace_suffix(text, " ", "")
    end
  end
end
