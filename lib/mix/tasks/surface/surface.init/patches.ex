defmodule Mix.Tasks.Surface.Init.Patches do
  @moduledoc false

  import Mix.Tasks.Surface.Init.ExPatcher
  alias Mix.Tasks.Surface.Init.ExPatcher

  def mix_compilers() do
    name = "Add :surface to compilers"

    instructions = """
    Append `:surface` to the list of compilers.

    # Example

    ```
    def project do
      [
        ...
        compilers: [:gettext] ++ Mix.compilers() ++ [:surface],
        ...
      ]
    end
    ```
    """

    patch = fn code ->
      code
      |> parse_string!()
      |> enter_defmodule()
      |> enter_def(:project)
      |> find_keyword_value(:compilers)
      |> halt_if(
        fn patcher -> node_to_string(patcher) == "[:gettext] ++ Mix.compilers() ++ [:surface]" end,
        :already_patched
      )
      |> halt_if(&find_code_containing(&1, ":surface"), :maybe_already_patched)
      |> append_child(" ++ [:surface]")
    end

    %{name: name, instructions: instructions, patch: patch}
  end

  def web_view_config(web_module) do
    name = "Add `import Surface` to view config"

    instructions = """
    In order to have `~F` available for any Phoenix view, you can import surface.

    # Example

    ```elixir
    def view do
      quote do
        ...
        import Surface
      end
    end
    ```
    """

    patch = fn code ->
      code
      |> parse_string!()
      |> enter_defmodule(web_module)
      # add it to view_helpers instead?
      |> enter_def(:view)
      |> enter_call(:quote)
      |> halt_if(&find_code_containing(&1, "import Surface"), :already_patched)
      |> append_child("\nimport Surface")
    end

    %{name: name, instructions: instructions, patch: patch}
  end

  def mix_exs_add_surface_catalogue_dep() do
    name = "Add `surface_catalogue` dependency"

    instructions = """
    TODO
    """

    patch = fn code ->
      code
      |> parse_string!()
      |> enter_defmodule()
      |> enter_defp(:deps)
      |> halt_if(&find_list_item_containing(&1, "{:surface_catalogue, "), :already_patched)
      |> append_list_item(
        ~S({:surface_catalogue, path: "../../surface_catalogue", only: [:test, :dev]}),
        preserve_indentation: true
      )
    end

    %{name: name, instructions: instructions, patch: patch}
  end

  def mix_exs_catalogue_update_elixirc_paths() do
    name = "Configure `elixirc_paths`"

    instructions = """
    TODO
    """

    add_elixirc_paths_dev_entry = fn code ->
      code
      |> parse_string!()
      |> enter_defmodule()
      |> halt_if(
        fn patcher ->
          find_defp_with_args(patcher, :elixirc_paths, &match?([":dev"], &1))
        end,
        :maybe_already_patched
      )
      |> find_code(~S|defp elixirc_paths(_), do: ["lib"]|)
      |> replace(&"defp elixirc_paths(:dev), do: [\"lib\"] ++ catalogues()\n  #{&1}")
    end

    add_catalogues_fun = fn code ->
      code
      |> parse_string!()
      |> enter_defmodule()
      |> halt_if(&find_def(&1, "catalogues"), :already_patched)
      |> last_child()
      |> replace_code(
        &"""
        #{&1}

          def catalogues do
            [
              "priv/catalogue"
            ]
          end\
        """
      )
    end

    %{name: name, instructions: instructions, patch: [add_elixirc_paths_dev_entry, add_catalogues_fun]}
  end

  def catalogue_router_config(web_module) do
    name = "Add `Surface.Catalogue.Router` to router config"

    instructions = """
    TODO
    """

    add_import = fn code ->
      code
      |> parse_string!()
      |> enter_defmodule(Module.concat(web_module, Router))
      |> halt_if(&find_code_containing(&1, "Surface.Catalogue.Router"), :already_patched)
      |> find_call_with_args(:use, fn args -> args == [inspect(web_module), ":router"] end)
      |> replace(&"#{&1}\n\n  import Surface.Catalogue.Router")
    end

    add_route = fn code ->
      code
      |> parse_string!()
      |> enter_defmodule(Module.concat(web_module, Router))
      |> halt_if(&find_code(&1, "surface_catalogue"), :already_patched)
      |> last_child()
      |> replace_code(
        &"""
        #{&1}

          if Mix.env() == :dev do
            scope "/" do
              pipe_through :browser
              surface_catalogue "/catalogue"
            end
          end\
        """
      )
    end

    %{name: name, instructions: instructions, patch: [add_import, add_route]}
  end

  def formatter_surface_inputs() do
    name = "Add file extensions to :surface_inputs"

    instructions = """
    In case you'll be using `mix format`, make sure you add the required file patterns
    to your `.formatter.exs` file.

    # Example

    ```
    [
      surface_inputs: ["{lib,test}/**/*.{ex,exs,sface}"],
      ...
    ]
    ```
    """

    patch = fn code ->
      code
      |> parse_string!()
      |> halt_if(&find_keyword(&1, :surface_inputs), :already_patched)
      |> append_keyword(:surface_inputs, ~S(["{lib,test}/**/*.{ex,exs,sface}"]))
    end

    %{name: name, instructions: instructions, patch: patch}
  end

  def formatter_import_deps() do
    name = "Add :surface to :import_deps"

    instructions = """
    In case you'll be using `mix format`, make sure you add `:surface` to the `import_deps`
    configuration in your `.formatter.exs` file.

    # Example

    ```
    [
      import_deps: [:ecto, :phoenix, :surface],
      ...
    ]
    ```
    """

    patch = fn code ->
      code
      |> parse_string!()
      |> find_keyword_value(:import_deps)
      |> halt_if(&find_list_item_with_code(&1, ":surface"), :already_patched)
      |> append_list_item(":surface")
    end

    %{name: name, instructions: instructions, patch: patch}
  end

  def endpoint_config_reloadable_compilers(context_app, web_module) do
    name = "Add :surface to :reloadable_compilers"

    instructions = """
    Add :surface to the list of reloadable compilers.

    # Example

    ```
    config :my_app, MyAppWeb.Endpoint,
      reloadable_compilers: [:phoenix, :elixir, :surface],
      ...
    ```
    """

    patch = fn code ->
      patcher =
        code
        |> parse_string!()
        |> find_endpoint_config_with_live_reload(context_app, web_module)

      case find_keyword(patcher, :reloadable_compilers) do
        %ExPatcher{node: nil} ->
          insert_keyword(patcher, :reloadable_compilers, "[:phoenix, :elixir, :surface]")

        list_patcher ->
          list_patcher
          |> value()
          |> halt_if(&find_list_item_with_code(&1, ":surface"), :already_patched)
          |> append_list_item(":surface")
      end
    end

    %{name: name, instructions: instructions, patch: patch}
  end

  def endpoint_config_live_reload_patterns(context_app, web_module, web_path) do
    name = "Update patterns in :reload_patterns"

    instructions = """
    Update the :reload_patterns entry to include surface-related files.

    # Example

    ```
    config :my_app, MyAppWeb.Endpoint,
      live_reload: [
        patterns: [
          ~r"lib/my_app_web/(live|views|components)/.*(ex|sface|js)$",
          ...
        ]
      ]
    ```
    """

    patch = fn code ->
      code
      |> parse_string!()
      |> find_endpoint_config_with_live_reload(context_app, web_module)
      |> find_keyword_value([:live_reload, :patterns])
      |> halt_if(&find_code_containing(&1, "sface"), :already_patched)
      |> find_list_item_with_code(~s[~r"#{web_path}/(live|views)/.*(ex)$"])
      |> replace(~s[~r"#{web_path}/(live|views|components)/.*(ex|sface|js)$"])
    end

    %{name: name, instructions: instructions, patch: patch}
  end

  def config_error_tag(web_module) do
    name = "Configure the ErrorTag component to use Gettext"

    instructions = """
    Set the `default_translator` option to the project's `ErrorHelpers.translate_error/1` function,
    which should be using Gettext for translations.

    # Example

    ```
    config :surface, :components, [
      ...
      {Surface.Components.Form.ErrorTag, default_translator: {MyAppWeb.ErrorHelpers, :translate_error}}
    ]
    ```
    """

    patch = fn code ->
      error_tag_item =
        "{Surface.Components.Form.ErrorTag, default_translator: {#{inspect(web_module)}.ErrorHelpers, :translate_error}}"

      patcher =
        code
        |> parse_string!()
        |> find_call_with_args(:config, &match?([":surface", ":components", _], &1))
        |> last_arg()

      case patcher do
        %ExPatcher{node: nil} ->
          code
          |> parse_string!()
          |> find_call_with_args(:config, &match?([":phoenix", ":json_library", _], &1))
          |> last_arg()
          |> replace(
            &"""
            #{&1}

            config :surface, :components, [
              #{error_tag_item}
            ]\
            """
          )

        components_patcher ->
          components_patcher
          |> halt_if(&find_list_item_containing(&1, "Surface.Components.Form.ErrorTag"), :already_patched)
          |> append_list_item(error_tag_item)
      end
    end

    %{name: name, instructions: instructions, patch: patch}
  end

  def endpoint_config_live_reload_patterns_for_catalogue(context_app, web_module) do
    name = "Update patterns in :reload_patterns to reload catalogue files"

    instructions = """
    Update the :reload_patterns entry to include catalogue files.

    # Example

    ```
    config :my_app, MyAppWeb.Endpoint,
      live_reload: [
        patterns: [
          ~r"priv/catalogue/.*(ex)$"
          ...
        ]
      ]
    ```
    """

    patch = fn code ->
      code
      |> parse_string!()
      |> find_endpoint_config_with_live_reload(context_app, web_module)
      |> find_keyword_value([:live_reload, :patterns])
      |> halt_if(&find_code_containing(&1, "catalogue"), :already_patched)
      # Could not use `append_list_item` as it messes with the indentation of the parent node
      |> down()
      |> last_child()
      |> replace_code(&"#{&1},\n      ~r\"priv/catalogue/.*(ex)$\"")
    end

    %{name: name, instructions: instructions, patch: patch}
  end

  def js_hooks() do
    name = "Configure components' JS hooks"

    instructions = """
    Import Surface components' hooks and pass them to `new LiveSocket(...)`.

    # Example

    ```JS
    import Hooks from "./_hooks"

    let liveSocket = new LiveSocket("/live", Socket, { hooks: Hooks, ... })
    ```
    """

    patch = fn code ->
      import_toolbar_string = ~S[import topbar from "../vendor/topbar"]
      import_hooks_string = ~S[import Hooks from "./_hooks"]

      live_socket_string = ~S[let liveSocket = new LiveSocket("/live", Socket, {params: {_csrf_token: csrfToken}})]

      patched_live_socket_string =
        ~S[let liveSocket = new LiveSocket("/live", Socket, {params: {_csrf_token: csrfToken}, hooks: Hooks})]

      already_patched? =
        Regex.match?(to_regex(import_hooks_string), code) and
          Regex.match?(to_regex(patched_live_socket_string), code)

      import_toolbar_regex = to_regex(import_toolbar_string)
      live_socket_regex = to_regex(live_socket_string)
      patchable? = Regex.match?(import_toolbar_regex, code) and Regex.match?(live_socket_regex, code)

      cond do
        already_patched? ->
          {:already_patched, code}

        patchable? ->
          updated_code = Regex.replace(import_toolbar_regex, code, ~s[\\0\n#{import_hooks_string}])
          updated_code = Regex.replace(live_socket_regex, updated_code, patched_live_socket_string)
          {:patched, updated_code}

        true ->
          {:file_modified, code}
      end
    end

    %{name: name, instructions: instructions, patch: patch}
  end

  defp find_endpoint_config_with_live_reload(patcher, context_app, web_module) do
    args = [inspect(context_app), "#{inspect(web_module)}.Endpoint"]

    patcher
    |> find_call_with_args_and_opt(:config, args, :live_reload)
    |> last_arg()
  end

  defp to_regex(string) do
    Regex.compile!("^#{Regex.escape(string)}$", "m")
  end
end
