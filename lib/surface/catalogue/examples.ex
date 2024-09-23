defmodule Surface.Catalogue.Examples do
  @moduledoc since: "0.8.0"
  @moduledoc ~S'''
  A generic LiveView to create multiple stateless examples for the Surface Catalogue.

  Each example must be a function component defined with the module attribute `@example`.

  > **NOTE**: If your examples require manipulating state (data) through `handle_event` callbacks,
  > use `Surface.Catalogue.LiveExample` instead.

  ## Options

  Besides the buit-in options provided by the LiveView itself, examples can also
  pass the following options at the module level:

    * `subject` - Required. The target component of the Example.

    * `catalogue` - Optional. A module that implements the `Surface.Catalogue`
      providing additional information to the catalogue tool. Usually required
      if you want to share your components as a library.

  Other options can be defined at the module level but also overridden at the
  function/example level using the `@example` module attribute. They are:

    * `height` - Required (either for the module or function). The height of the Example.

    * `title` - Optional. The title of the example.

    * `body` - Optional. Sets/overrides the attributes of the the Example's body tag.
      Useful to set a different background or padding.

    * `direction` - Optional. Defines how the example + code boxes should be displayed.
      Available values are "horizontal" or "vertical". Default is "horizontal" (side-by-side).

    * `code_perc` - Optional. When the direction is "horizontal", defines the percentage of
      the total width that the code box should take. Default is `50`. Note: This configuration
      has no effect when direction is "vertical".

    * `assert` - Optional. When using `catalogue_test/1`, generates simple `=~` assertions for
      the given text or list of texts.

  When defined at the module level, i.e. passing to `use Surface.Catalogue.Examples, ...`, the
  options apply to all examples. Aside from `subject` and `catalogue`, options can be overridden
  at the function level using the `@example` module attribute.

  ## Examples

  ### Basic usage

  ```
  @example true
  def basic_example(assigns) do
    ~F"""
    <Button>OK</Button>
    """
  end
  ```

  ### Defining a custom title + docs

  ```
  @example "Example with docs"
  @doc "A simple example with documentation"
  def example_01(assigns) do
    ~F"""
    <Button>OK</Button>
    """
  end
  ```

  ### Defining other options

  ```
  @example [
    title: "Example and Code split vertically",
    direction: "vertical",
    height: "110px",
    assert: ["Small", "Medium", "Large"]
  ]
  def vertical(assigns) do
    ~F"""
    <Button size="small" color="info">Small</Button>
    <Button size="medium" color="warning">Medium</Button>
    <Button size="large" color="danger">Large</Button>
    """
  end
  ```

  Notice that whenever you want to pass other options using a keyword list as in the
  example above, in case you need to customize the title, it must to be passed as
  a key/value option as well.
  '''

  defmacro __using__(opts) do
    subject = Surface.Catalogue.fetch_subject!(opts, __MODULE__, __CALLER__)
    Module.register_attribute(__CALLER__.module, :__examples__, accumulate: true)

    quote do
      @after_compile unquote(__MODULE__)
      @__use_line__ unquote(__CALLER__.line)
      @before_compile unquote(__MODULE__)
      @on_definition unquote(__MODULE__)

      use Surface.LiveView, unquote(opts)

      alias unquote(subject)
      require Surface.Catalogue.Data, as: Data

      @__example_config__ unquote(opts)

      import Surface, except: [sigil_F: 2]

      on_mount({unquote(__MODULE__), :assign_func})

      Module.register_attribute(__MODULE__, :__example_codes__, accumulate: true)

      defmacrop sigil_F({:<<>>, _meta, [string]} = ast, opts) do
        Module.put_attribute(__CALLER__.module, :__example_codes__, string)

        quote do
          Surface.sigil_F(unquote(ast), unquote(opts))
        end
      end

      def render(%{__func__: _} = var!(assigns)) do
        ~F"""
        <Component module={__MODULE__} function={@__func__}/>
        """
      end
    end
  end

  defmacro __before_compile__(env) do
    config = Module.get_attribute(env.module, :__example_config__)
    subject = Keyword.fetch!(config, :subject)
    codes = Module.get_attribute(env.module, :__example_codes__)

    examples_configs =
      Module.get_attribute(env.module, :__examples__, [[]])
      |> Enum.zip_with(codes, fn map, code -> Keyword.put(map, :code, code) end)
      |> Enum.reverse()

    quote do
      @moduledoc catalogue: [
                   type: :example,
                   subject: unquote(subject),
                   config: unquote(config),
                   examples_configs: unquote(examples_configs)
                 ]
    end
  end

  def __after_compile__(env, _) do
    case Module.get_attribute(env.module, :__example_config__)[:catalogue] do
      nil ->
        nil

      module ->
        case Code.ensure_compiled(module) do
          {:module, _mod} ->
            nil

          {:error, _} ->
            message =
              "defined catalogue `#{inspect(module)}` could not be found"

            Surface.IOHelper.compile_error(message, env.file, Module.get_attribute(env.module, :__use_line__))
        end
    end
  end

  def __on_definition__(env, :def, name, [_arg], _guards, _body) when name != :render do
    doc = Module.get_attribute(env.module, :doc)

    config =
      env.module
      |> Module.get_attribute(:example)
      |> init_config(name, env)
      |> maybe_put_doc(doc)

    if config do
      Module.delete_attribute(env.module, :example)
      Module.put_attribute(env.module, :__examples__, config)
    end
  end

  def __on_definition__(_env, _kind, _name, _args, _guards, _body) do
    :ok
  end

  @doc false
  def on_mount(:assign_func, _params, session, socket) do
    func = session["func"] |> String.to_existing_atom()
    {:cont, Phoenix.Component.assign(socket, __func__: func)}
  end

  defp init_config(nil, _name, _env), do: nil

  defp init_config(config, name, env) do
    default_config = [func: name, title: Phoenix.Naming.humanize(name), line: env.line]

    case config do
      true ->
        default_config

      title when is_binary(title) ->
        Keyword.put(default_config, :title, title)

      config when is_list(config) ->
        Keyword.merge(default_config, config)
    end
  end

  defp maybe_put_doc(nil, _doc), do: nil
  defp maybe_put_doc(config, {_, doc}), do: Keyword.put(config, :doc, doc)
  defp maybe_put_doc(config, _doc), do: config
end
