defmodule Mix.Tasks.Surface.Init.FilePatchers.Formatter do
  @moduledoc false

  # Common patches for `.formatter`

  import Mix.Tasks.Surface.Init.ExPatcher
  alias Mix.Tasks.Surface.Init.ExPatcher

  def add_config(code, key, value) do
    code
    |> parse_string!()
    |> halt_if(&find_keyword(&1, key), :already_patched)
    |> append_keyword(key, value)
  end

  def add_import_dep(code, dep) do
    code
    |> parse_string!()
    |> find_keyword_value(:import_deps)
    |> halt_if(&find_list_item_with_code(&1, dep), :already_patched)
    |> append_list_item(dep)
  end

  def add_input(code, pattern) do
    code
    |> parse_string!()
    |> find_keyword_value(:inputs)
    |> halt_if(&find_list_item_with_code(&1, pattern), :already_patched)
    |> append_list_item(pattern)
  end

  def add_plugin(code, plugin) do
    patcher = parse_string!(code)

    case find_keyword_value(patcher, :plugins) do
      %ExPatcher{node: nil} ->
        append_keyword(patcher, :plugins, "[#{plugin}]")

      plugins_patcher ->
        plugins_patcher
        |> halt_if(&find_list_item_with_code(&1, plugin), :already_patched)
        |> append_list_item(plugin)
    end
  end
end
