defmodule Mix.Tasks.Surface.Init.ProjectPatchers.Layouts do
  @moduledoc false

  alias Mix.Tasks.Surface.Init.FilePatchers

  @behaviour Mix.Tasks.Surface.Init.ProjectPatcher

  @impl true
  def file_patchers(%{layouts: true} = assigns) do
    %{
      web_module: web_module,
      web_path: web_path,
      web_module_path: web_module_path
    } = assigns

    %{
      web_module_path => [
        add_layout_config_to_view_macro(web_path, web_module)
      ]
    }
  end

  def file_patchers(_assigns) do
    # TODO
    []
  end

  @impl true
  def create_files(_assigns), do: []

  def add_layout_config_to_view_macro(web_path, web_module) do
    %{
      name: "Configure `Surface.View` in view config",
      patch:
        &FilePatchers.Phoenix.append_code_to_view_macro(
          &1,
          ~s[use Surface.View, root: "#{web_path}/templates"],
          web_module
        ),
      instructions: """
      Set up `Surface.View` in your view config so you can uses Surface files as dead views/layouts.

      # Example

      ```elixir
      def view do
        quote do
          ...
          use Surface.View, root: "my_app_web/templates"\
        end
      end
      ```
      """
    }
  end
end
