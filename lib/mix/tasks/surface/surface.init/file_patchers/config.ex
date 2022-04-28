defmodule Mix.Tasks.Surface.Init.FilePatchers.Config do
  @moduledoc false

  # Common patches for config files

  alias Mix.Tasks.Surface.Init.ExPatcher
  import ExPatcher

  def add_root_config(code, key, value) do
    key_str = inspect(key)

    code
    |> parse_string!()
    |> halt_if(
      fn patcher -> find_call_with_args(patcher, :config, &match?([^key_str, _], &1)) end,
      :already_patched
    )
    |> find_call_with_args(:import, &(&1 == ["Config"]))
    |> append_code("""

    #{value}\
    """)
  end
end
