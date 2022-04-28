defmodule Mix.Tasks.Surface.Init.ProjectPatchers.DemoTest do
  use ExUnit.Case, async: true

  alias Mix.Tasks.Surface.Init.Patcher
  import Mix.Tasks.Surface.Init.ProjectPatchers.Demo

  describe "configure_demo_route" do
    test "add the demo route" do
      code = """
      defmodule MyAppWeb.Router do
        use MyAppWeb, :router

        scope "/", MyAppWeb do
          pipe_through :browser

          get "/", PageController, :index
        end
      end
      """

      {:patched, updated_code} = Patcher.patch_code(code, configure_demo_route(MyAppWeb))

      assert updated_code == """
             defmodule MyAppWeb.Router do
               use MyAppWeb, :router

               scope "/", MyAppWeb do
                 pipe_through :browser

                 get "/", PageController, :index
                 live "/demo", Demo
               end
             end
             """
    end

    test "don't apply it if already patched" do
      code = """
      defmodule MyAppWeb.Router do
        use MyAppWeb, :router

        scope "/", MyAppWeb do
          pipe_through :browser

          get "/", PageController, :index
          live "/demo", Demo
        end
      end
      """

      assert {:already_patched, ^code} = Patcher.patch_code(code, configure_demo_route(MyAppWeb))
    end
  end
end
