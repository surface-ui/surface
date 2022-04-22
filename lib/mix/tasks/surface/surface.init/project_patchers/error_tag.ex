defmodule Mix.Tasks.Surface.Init.ProjectPatchers.ErrorTag do
  @moduledoc false

  alias Mix.Tasks.Surface.Init.FilePatchers

  @behaviour Mix.Tasks.Surface.Init.ProjectPatcher

  @impl true
  def file_patchers(%{error_tag: true, using_gettext?: true} = assigns) do
    %{web_module: web_module} = assigns

    %{
      "config/config.exs" => [
        config_error_tag(web_module)
      ]
    }
  end

  def file_patchers(_assigns), do: []

  @impl true
  def create_files(_assigns), do: []

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

    patch =
      &FilePatchers.Component.add_config(
        &1,
        "Surface.Components.Form.ErrorTag",
        "default_translator: {#{inspect(web_module)}.ErrorHelpers, :translate_error}"
      )

    %{name: name, instructions: instructions, patch: patch}
  end
end
