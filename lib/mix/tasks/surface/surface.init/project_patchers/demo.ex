defmodule Mix.Tasks.Surface.Init.ProjectPatchers.Demo do
  @moduledoc false

  alias Mix.Tasks.Surface.Init.FilePatchers

  @behaviour Mix.Tasks.Surface.Init.ProjectPatcher

  @impl true
  def file_patchers(%{demo: true} = assigns) do
    %{web_module: web_module, web_path: web_path} = assigns

    %{
      "#{web_path}/router.ex" => [
        configure_demo_route(web_module)
      ]
    }
  end

  def file_patchers(_assigns), do: []

  @impl true
  def create_files(%{demo: true} = assigns) do
    %{web_path: web_path} = assigns

    [
      {:create, "demo/hero.ex", Path.join([web_path, "components"])},
      {:create, "demo/demo.ex", Path.join([web_path, "live"])}
    ]
  end

  def create_files(_assigns), do: []

  def configure_demo_route(web_module) do
    %{
      name: "Configure demo route",
      patch: &FilePatchers.Phoenix.append_route_to_main_scope(&1, ~S("/demo"), web_module, ~S(live "/demo", Demo)),
      instructions: """
      Update your `router.ex` configuration so the demo can be available at `/demo`.

      # Example

      ```
      scope "/", MyAppWeb do
        pipe_through :browser

        live "/demo", Demo
      end
      ```
      """
    }
  end
end
