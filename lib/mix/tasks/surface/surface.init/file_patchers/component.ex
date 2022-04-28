defmodule Mix.Tasks.Surface.Init.FilePatchers.Component do
  @moduledoc false

  alias Mix.Tasks.Surface.Init.ExPatcher
  import ExPatcher

  def add_config(code, component, config) do
    config_entry = "{#{component}, #{config}}"

    patcher =
      code
      |> parse_string!()
      |> find_call_with_args(:config, &match?([":surface", ":components", _], &1))
      |> last_arg()

    case patcher do
      %ExPatcher{node: nil} ->
        code
        |> parse_string!()
        |> find_call_with_args(:import, &(&1 == ["Config"]))
        |> append_code("""

        config :surface, :components, [
          #{config_entry}
        ]\
        """)

      components_patcher ->
        components_patcher
        |> halt_if(&find_list_item_containing(&1, component), :already_patched)
        |> append_list_item(config_entry)
    end
  end
end
