defmodule Surface.Compiler.Converter_0_8 do
  @moduledoc false

  @behaviour Surface.Compiler.Converter

  @impl true
  def after_convert_file(_ext, content), do: content

  @impl true
  def opts() do
    [handle_full_node: ["#template"]]
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

  def convert(:tag_close, "</#template>", %{slot_name: slot_name}, _opts) do
    "</:#{slot_name}>"
  end

  def convert(_type, text, _state, _opts) do
    text
  end
end
