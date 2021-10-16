defmodule Mix.Tasks.Surface.Init.Patchers.Phoenix do
  @moduledoc false

  # Common patches for phoenix projects

  alias Mix.Tasks.Surface.Init.ExPatcher
  import ExPatcher

  def add_import_to_view_macro(code, module, web_module) do
    import_str = "import #{inspect(module)}"

    code
    |> parse_string!()
    |> enter_defmodule(web_module)
    |> enter_def(:view)
    |> enter_call(:quote)
    |> halt_if(&find_code_containing(&1, import_str), :already_patched)
    |> append_child("\n#{import_str}")
  end

  def add_import_to_router(code, module, web_module) do
    import_str = "import #{inspect(module)}"

    code
    |> parse_string!()
    |> enter_defmodule(Module.concat(web_module, Router))
    |> halt_if(&find_code_containing(&1, import_str), :already_patched)
    |> find_call_with_args(:use, fn args -> args == [inspect(web_module), ":router"] end)
    |> replace(&"#{&1}\n\n  #{import_str}")
  end

  def append_route(code, route, web_module, route_code) do
    code
    |> parse_string!()
    |> enter_defmodule(Module.concat(web_module, Router))
    |> halt_if(&find_code(&1, route), :already_patched)
    |> last_child()
    |> replace_code(&"#{&1}\n\n#{route_code}")
  end

  def append_route_to_main_scope(code, route, web_module, route_code) do
    web_module_str = inspect(web_module)

    code
    |> parse_string!()
    |> enter_defmodule(Module.concat(web_module, Router))
    |> halt_if(&find_code(&1, route), :already_patched)
    |> find_call_with_args(:scope, &match?([~S("/"), ^web_module_str | _], &1))
    |> body()
    |> last_child()
    |> replace_code(&"#{&1}\n    #{route_code}")
  end

  def add_reloadable_compiler_to_endpoint_config(code, compiler, context_app, web_module) do
    reloadable_compilers = Module.concat(web_module, Endpoint).config(:reloadable_compilers)

    patcher =
      code
      |> parse_string!()
      |> find_endpoint_config_with_live_reload(context_app, web_module)

    case find_keyword(patcher, :reloadable_compilers) do
      %ExPatcher{node: nil} ->
        value = inspect(reloadable_compilers ++ [compiler])
        insert_keyword(patcher, :reloadable_compilers, value)

      list_patcher ->
        list_patcher
        |> value()
        |> halt_if(&find_list_item_with_code(&1, inspect(compiler)), :already_patched)
        |> append_list_item(inspect(compiler))
    end
  end

  def add_live_reload_pattern_to_endpoint_config(code, pattern, already_pached_text, context_app, web_module) do
    code
    |> parse_string!()
    |> find_endpoint_config_with_live_reload(context_app, web_module)
    |> find_keyword_value([:live_reload, :patterns])
    |> halt_if(&find_code_containing(&1, already_pached_text), :already_patched)
    # Could not use `append_list_item` as it messes with the indentation of the parent node
    |> down()
    |> last_child()
    |> replace_code(&"#{&1},\n      #{pattern}")
  end

  def replace_live_reload_pattern_in_endpoint_config(
        code,
        pattern,
        replacement,
        already_pached_text,
        context_app,
        web_module
      ) do
    code
    |> parse_string!()
    |> find_endpoint_config_with_live_reload(context_app, web_module)
    |> find_keyword_value([:live_reload, :patterns])
    |> halt_if(&find_code_containing(&1, already_pached_text), :already_patched)
    |> find_list_item_with_code(pattern)
    |> replace(replacement)
  end

  defp find_endpoint_config_with_live_reload(patcher, context_app, web_module) do
    args = [inspect(context_app), "#{inspect(web_module)}.Endpoint"]

    patcher
    |> find_call_with_args_and_opt(:config, args, :live_reload)
    |> last_arg()
  end
end
