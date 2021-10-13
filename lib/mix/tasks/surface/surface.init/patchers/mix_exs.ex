defmodule Mix.Tasks.Surface.Init.Patchers.MixExs do
  @moduledoc false

  import Mix.Tasks.Surface.Init.ExPatcher

  def add_compiler(code, compiler) do
    code
    |> parse_string!()
    |> enter_defmodule()
    |> enter_def(:project)
    |> find_keyword_value(:compilers)
    |> halt_if(
      fn patcher -> node_to_string(patcher) == "[:gettext] ++ Mix.compilers() ++ [#{compiler}]" end,
      :already_patched
    )
    |> halt_if(&find_code_containing(&1, compiler), :maybe_already_patched)
    |> append_child(" ++ [#{compiler}]")
  end

  def add_dep(code, dep, opts) do
    code
    |> parse_string!()
    |> enter_defmodule()
    |> enter_defp(:deps)
    |> halt_if(&find_list_item_containing(&1, "{#{dep}, "), :already_patched)
    |> append_list_item(~s({#{dep}, #{opts}}), preserve_indentation: true)
  end

  def append_def(code, def, body) do
    code
    |> parse_string!()
    |> enter_defmodule()
    |> halt_if(&find_def(&1, def), :already_patched)
    |> last_child()
    |> replace_code(
      &"""
      #{&1}

        def #{def} do
      #{body}
        end\
      """
    )
  end
end
