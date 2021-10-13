defmodule Mix.Tasks.Surface.Init.Patchers.Phoenix do
  @moduledoc false

  import Mix.Tasks.Surface.Init.ExPatcher
  # alias Mix.Tasks.Surface.Init.ExPatcher

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

  # def endpoint_config_reloadable_compilers(context_app, web_module) do
  #   name = "Add :surface to :reloadable_compilers"

  #   instructions = """
  #   Add :surface to the list of reloadable compilers.

  #   # Example

  #   ```
  #   config :my_app, MyAppWeb.Endpoint,
  #     reloadable_compilers: [:phoenix, :elixir, :surface],
  #     ...
  #   ```
  #   """

  #   patch = fn code ->
  #     patcher =
  #       code
  #       |> parse_string!()
  #       |> find_endpoint_config_with_live_reload(context_app, web_module)

  #     case find_keyword(patcher, :reloadable_compilers) do
  #       %ExPatcher{node: nil} ->
  #         insert_keyword(patcher, :reloadable_compilers, "[:phoenix, :elixir, :surface]")

  #       list_patcher ->
  #         list_patcher
  #         |> value()
  #         |> halt_if(&find_list_item_with_code(&1, ":surface"), :already_patched)
  #         |> append_list_item(":surface")
  #     end
  #   end

  #   %{name: name, instructions: instructions, patch: patch}
  # end

  # def endpoint_config_live_reload_patterns(context_app, web_module, web_path) do
  #   name = "Update patterns in :reload_patterns"

  #   instructions = """
  #   Update the :reload_patterns entry to include surface-related files.

  #   # Example

  #   ```
  #   config :my_app, MyAppWeb.Endpoint,
  #     live_reload: [
  #       patterns: [
  #         ~r"lib/my_app_web/(live|views|components)/.*(ex|sface|js)$",
  #         ...
  #       ]
  #     ]
  #   ```
  #   """

  #   patch = fn code ->
  #     code
  #     |> parse_string!()
  #     |> find_endpoint_config_with_live_reload(context_app, web_module)
  #     |> find_keyword_value([:live_reload, :patterns])
  #     |> halt_if(&find_code_containing(&1, "sface"), :already_patched)
  #     |> find_list_item_with_code(~s[~r"#{web_path}/(live|views)/.*(ex)$"])
  #     |> replace(~s[~r"#{web_path}/(live|views|components)/.*(ex|sface|js)$"])
  #   end

  #   %{name: name, instructions: instructions, patch: patch}
  # end

  # def endpoint_config_live_reload_patterns_for_catalogue(context_app, web_module) do
  #   name = "Update patterns in :reload_patterns to reload catalogue files"

  #   instructions = """
  #   Update the :reload_patterns entry to include catalogue files.

  #   # Example

  #   ```
  #   config :my_app, MyAppWeb.Endpoint,
  #     live_reload: [
  #       patterns: [
  #         ~r"priv/catalogue/.*(ex)$"
  #         ...
  #       ]
  #     ]
  #   ```
  #   """

  #   patch = fn code ->
  #     code
  #     |> parse_string!()
  #     |> find_endpoint_config_with_live_reload(context_app, web_module)
  #     |> find_keyword_value([:live_reload, :patterns])
  #     |> halt_if(&find_code_containing(&1, "catalogue"), :already_patched)
  #     # Could not use `append_list_item` as it messes with the indentation of the parent node
  #     |> down()
  #     |> last_child()
  #     |> replace_code(&"#{&1},\n      ~r\"priv/catalogue/.*(ex)$\"")
  #   end

  #   %{name: name, instructions: instructions, patch: patch}
  # end

  # defp find_endpoint_config_with_live_reload(patcher, context_app, web_module) do
  #   args = [inspect(context_app), "#{inspect(web_module)}.Endpoint"]

  #   patcher
  #   |> find_call_with_args_and_opt(:config, args, :live_reload)
  #   |> last_arg()
  # end
end
