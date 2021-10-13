defmodule Mix.Tasks.Surface.Init.Patchers.Formatter do
  @moduledoc false

  import Mix.Tasks.Surface.Init.ExPatcher

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
end
