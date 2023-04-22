defmodule Mix.Tasks.Surface.Init.FilePatchers.MixExs do
  @moduledoc false

  # Common patches for `mix.exs`

  import Mix.Tasks.Surface.Init.ExPatcher
  alias Mix.Tasks.Surface.Init.ExPatcher

  def add_compiler(code, compiler) do
    patcher =
      code
      |> parse_string!()
      |> enter_defmodule()
      |> enter_def(:project)

    case find_keyword_value(patcher, :compilers) do
      %ExPatcher{node: nil} ->
        patcher
        |> append_keyword(:compilers, "Mix.compilers() ++ [#{compiler}]")

      compilers_patcher ->
        compilers_patcher
        |> halt_if(&find_code_containing(&1, compiler), :already_patched)
        |> append_child(" ++ [#{compiler}]")
    end
  end

  def add_dep(code, dep, opts) do
    code
    |> parse_string!()
    |> enter_defmodule()
    |> enter_defp(:deps)
    |> halt_if(&find_list_item_containing(&1, "{#{dep},"), :already_patched)
    |> append_list_item(~s({#{dep}, #{opts}}), preserve_indentation: true)
  end

  def append_def(code, def, body) do
    code
    |> parse_string!()
    |> enter_defmodule()
    |> halt_if(&find_def(&1, def), :already_patched)
    |> append_code("""

    def #{def} do
    #{body}
    end\
    """)
  end

  def add_elixirc_paths_entry(code, env, body, already_patched_text) do
    code
    |> parse_string!()
    |> enter_defmodule()
    |> halt_if(
      fn patcher ->
        patcher
        |> find_defp_with_args(:elixirc_paths, &match?([^env], &1))
        |> body()
        |> find_code(already_patched_text)
      end,
      :already_patched
    )
    |> halt_if(
      fn patcher -> find_defp_with_args(patcher, :elixirc_paths, &match?([^env], &1)) end,
      :maybe_already_patched
    )
    |> find_code(~S|defp elixirc_paths(_), do: ["lib"]|)
    |> replace(&"defp elixirc_paths(#{env}), do: #{body}\n#{&1}")
  end

  def update_elixirc_paths_entry(code, env, update_fun, already_patched_text) do
    code
    |> parse_string!()
    |> enter_defmodule()
    |> find_defp_with_args(:elixirc_paths, &match?([^env], &1))
    |> body()
    |> halt_if(&find_code(&1, already_patched_text), :already_patched)
    |> replace(update_fun)
  end

  def update_alias(code, key, already_patched_text, maybe_already_patched, fun) do
    code
    |> parse_string!()
    |> enter_defmodule()
    |> enter_defp(:aliases)
    |> find_keyword_value(key)
    |> halt_if(
      fn patcher -> node_to_string(patcher) == already_patched_text end,
      :already_patched
    )
    |> halt_if(&find_code_containing(&1, maybe_already_patched), :maybe_already_patched)
    |> fun.()
  end
end
