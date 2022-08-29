defmodule Surface.Compiler.Converter_0_8 do
  @moduledoc false

  @behaviour Surface.Compiler.Converter

  @impl true
  def after_convert_file(_ext, content), do: content

  @impl true
  def opts() do
    [handle_full_node: ["#template", "#slot"]]
  end

  @impl true
  def convert(:tag_open_begin, "<#template", _state, _opts) do
    "<:"
  end

  def convert(:tag_open_end, ">", %{tag_open_begin: "<#template"} = state, _opts) do
    slot = "default"
    {"#{String.trim(slot)}>", Map.put(state, :slot_name, slot)}
  end

  def convert(:tag_open_end, text, %{tag_open_begin: "<#template"} = state, _opts) do
    [_, slot] = Regex.run(~r/slot="(\w+)"/s, text)
    {"#{String.trim(slot)}>", Map.put(state, :slot_name, slot)}
  end

  def convert(:tag_close, "</#template>", %{slot_name: slot_name} = state, _opts) do
    {"</:#{slot_name}>", Map.delete(state, :slot_name)}
  end

  def convert(:tag_open_end, text, %{tag_open_begin: "<#slot" = begin}, _opts) do
    {attrs, self_close} = extract_tag_attrs(begin, text, extract: ["index", "name", "for", ":args"])
    can_convert? = Enum.any?(attrs, fn {k, v} -> k == "index" and is_nil(v) end)
    needs_convertion? = Enum.any?(attrs, fn {k, v} -> k != :others and !is_nil(v) end)

    if can_convert? and needs_convertion? do
      " #{new_slot_attrs(attrs)}#{tag_close_text(self_close)}"
    else
      text
    end
  end

  def convert(_type, text, _state, _opts) do
    text
  end

  defp extract_tag_attrs(begin, text, opts) do
    extract = Keyword.get(opts, :extract, [])

    [{:tag_open, "#slot", attrs_tokens, %{ignored_body?: false, self_close: self_close}}] =
      Surface.Compiler.Tokenizer.tokenize!(begin <> text)

    attrs =
      for {attr_name, {attr_type, attr_value, _value_meta}, _attr_meta} <- attrs_tokens,
          reduce: %{others: []} |> Map.merge(Map.new(extract, &{&1, nil})) do
        acc ->
          if attr_name in extract do
            Map.put(acc, attr_name, attr_value)
          else
            Map.update!(acc, :others, &[{attr_name, attr_type, attr_value} | &1])
          end
      end

    {attrs, self_close}
  end

  defp new_slot_attrs(attrs) do
    root_expr = [slot_name(attrs), attrs[":args"]] |> Enum.reject(&is_nil/1) |> Enum.join(", ")
    attrs_text([{:root, :expr, root_expr} | Enum.reverse(attrs.others)])
  end

  defp slot_name(%{"name" => nil, "for" => nil}), do: "@default"
  defp slot_name(%{"name" => name, "for" => nil}), do: "@#{name}"
  defp slot_name(%{"name" => nil, "for" => for_text}), do: for_text

  defp attrs_text(attrs) do
    attrs |> Enum.map(&attr_text/1) |> Enum.join(" ")
  end

  defp attr_text({:root, :expr, attr_value}), do: "{#{attr_value}}"
  defp attr_text({attr_name, :expr, attr_value}), do: "#{attr_name}={#{attr_value}}"

  defp tag_close_text(self_close)
  defp tag_close_text(true), do: " />"
  defp tag_close_text(false), do: ">"
end
