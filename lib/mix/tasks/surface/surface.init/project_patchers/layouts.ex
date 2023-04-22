defmodule Mix.Tasks.Surface.Init.ProjectPatchers.Layouts do
  @moduledoc false

  @behaviour Mix.Tasks.Surface.Init.ProjectPatcher

  alias Mix.Tasks.Surface.Init.FilePatchers

  @impl true
  def specs(%{layouts: true} = assigns) do
    %{web_path: web_path, web_module: web_module} = assigns

    [
      {:patch, "#{web_path}/components/layouts.ex", [add_embed_sface_calls_to_layouts(web_module)]},
      {:create, "layouts/app.sface", Path.join(web_path, "components/layouts")},
      {:delete, Path.join(web_path, "components/layouts/app.html.heex")},
      {:create, "layouts/root.sface", Path.join(web_path, "components/layouts")},
      {:delete, Path.join(web_path, "components/layouts/root.html.heex")}
    ]
  end

  def specs(_assigns), do: []

  def add_embed_sface_calls_to_layouts(web_module) do
    %{
      name: "Embed sface templates in the Layouts module",
      patch:
        &FilePatchers.Phoenix.append_code_to_layouts_module(
          &1,
          """
          embed_sface "layouts/root.sface"
          embed_sface "layouts/app.sface"\
          """,
          "embed_sface",
          Module.concat(web_module, "Layouts")
        ),
      instructions: """
      If you want to use `.sface` files instead of `.html.heex` files as your layout templates,
      use the `embed_sface` macro to embed the templates in your Layouts module.

      # Example

      ```
      defmodule #{inspect(web_module)}.Layouts do
        use MyAppWeb, :html

        embed_sface "layouts/root.sface"
        embed_sface "layouts/app.sface"
      end
      ```
      """
    }
  end
end
