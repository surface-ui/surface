defmodule Surface.Catalogue do
  @moduledoc """
  A behaviour to provide additional information about the catalogue.

  Optional for local catalogues. Usually required if you want to share
  your components as a library.
  """

  @doc """
  Returns a keyword list of config options to be used by the catalogue tool.

  Available options:

    * `head_css` - CSS related content to be added to the `<head>...</head>` section
      of each example or playground.

    * `head_js` - JS related content to be added to the `<head>...</head>` section
      of each example or playground.

    * `example` - A keyword list of options to be applied for all examples
      in in the catalogue.

    * `playground` - A keyword list of options to be applied for all playgrounds
      in in the catalogue.

  """
  @callback config :: keyword()

  @default_config [
    head_css: """
    <link phx-track-static rel="stylesheet" href="/css/app.css"/>
    """,
    head_js: """
    <script defer type="module" src="/js/app.js"></script>
    """
  ]

  defmacro __using__(_opts) do
    quote do
      @behaviour Surface.Catalogue

      import Surface.Catalogue, only: [load_asset: 2]
    end
  end

  @doc """
  Loads a text file as module attribute so you can inject its content directly
  in `head_css` or `head_js` config options.

  Useful to avoid depending on external css or js code. The path should be relative
  to the caller's folder.

  Available options:

    * `as` - the name of the module attribute to be generated.

  """
  defmacro load_asset(file, opts) do
    as = Keyword.fetch!(opts, :as)

    quote do
      path = Path.join(__DIR__, unquote(file))
      @external_resource path
      Module.put_attribute(__MODULE__, unquote(as), File.read!(path))
    end
  end

  @doc false
  def get_metadata(module) do
    case Code.fetch_docs(module) do
      {:docs_v1, _, _, "text/markdown", docs, %{catalogue: meta}, _} ->
        doc = Map.get(docs, "en")
        meta |> Map.new() |> Map.put(:doc, doc)

      _ ->
        nil
    end
  end

  @doc false
  def get_config(module) do
    meta = get_metadata(module)
    user_config = Map.get(meta, :config, [])
    catalogue = Keyword.get(user_config, :catalogue)
    catalogue_config = get_catalogue_config(catalogue)
    {type_config, catalogue_config} = Keyword.split(catalogue_config, [:example, :playground])

    @default_config
    |> Keyword.merge(catalogue_config)
    |> Keyword.merge(type_config[meta.type] || [])
    |> Keyword.merge(user_config)
  end

  @doc false
  def fetch_subject!(config, type, caller) do
    case Keyword.fetch(config, :subject) do
      {:ok, subject} ->
        subject

      _ ->
        message = """
        no subject defined for #{inspect(type)}

        Hint: You can define the subject using the :subject option. Example:

          use #{inspect(type)}, subject: MyApp.MyButton
        """

        Surface.IOHelper.compile_error(message, caller.file, caller.line)
    end
  end

  defp get_catalogue_config(nil) do
    []
  end

  defp get_catalogue_config(catalogue) do
    if module_loaded?(catalogue) do
      catalogue.config()
    else
      []
    end
  end

  defp module_loaded?(module) do
    match?({:module, _mod}, Code.ensure_compiled(module))
  end
end
