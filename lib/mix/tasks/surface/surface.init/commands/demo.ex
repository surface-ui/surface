defmodule Mix.Tasks.Surface.Init.Commands.Demo do
  alias Mix.Tasks.Surface.Init.Patchers

  @behaviour Mix.Tasks.Surface.Init.Command

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
  def create_files(_assigns), do: []

  def configure_demo_route(web_module) do
    %{
      name: "Configure demo route",
      patch: &Patchers.Phoenix.append_route_to_main_scope(&1, ~S("/demo"), web_module, ~S(live "/demo", Demo)),
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
