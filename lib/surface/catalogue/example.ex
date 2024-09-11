defmodule Surface.Catalogue.Example do
  @moduledoc """
  A generic LiveView to create a single example for catalogue tools.

  ## Options

  Besides the buit-in options provided by the LiveView itself, an Example also
  provides the following options:

    * `subject` - Required. The target component of the Example.

    * `height` - Required. The height of the Example.

    * `catalogue` - Optional. A module that implements the `Surface.Catalogue`
      providing additional information to the catalogue tool. Usually required
      if you want to share your components as a library.

    * `body` - Optional. Sets/overrides the attributes of the the Example's body tag.
      Useful to set a different background or padding.

    * `title` - Optional. The title of the example.

    * `direction` - Optional. Defines how the example + code boxes should be displayed.
      Available values are "horizontal" or "vertical". Default is "horizontal" (side-by-side).

    * `code_perc` - Optional. When the direction is "horizontal", defines the percentage of
      the total width that the code box should take. Default is `50`. Note: This configuration
      has no effect when direction is "vertical".

    * `assert` - Optional. When using `catalogue_test/1`, generates simple `=~` assertions for
      the given text or list of texts.

  """

  defmacro __using__(opts) do
    subject = Surface.Catalogue.fetch_subject!(opts, __MODULE__, __CALLER__)

    quote do
      @__example_config__ unquote(opts)
      @__use_line__ unquote(__CALLER__.line)
      @after_compile unquote(__MODULE__)
      @before_compile unquote(__MODULE__)

      use Surface.LiveView, unquote(opts)

      alias unquote(subject)
      require Surface.Catalogue.Data, as: Data

      import Surface, except: [sigil_F: 2]

      defmacrop sigil_F({:<<>>, _meta, [string]} = ast, opts) do
        Module.put_attribute(__CALLER__.module, :__example_code__, string)

        quote do
          Surface.sigil_F(unquote(ast), unquote(opts))
        end
      end
    end
  end

  defmacro __before_compile__(env) do
    config = Module.get_attribute(env.module, :__example_config__)
    subject = Keyword.fetch!(config, :subject)
    assert = Keyword.get(config, :assert, [])

    code = Module.get_attribute(env.module, :__example_code__)
    line = Module.get_attribute(env.module, :__example_line__)

    doc =
      case Module.get_attribute(env.module, :moduledoc) do
        {_, doc} -> doc
        _ -> nil
      end

    examples_configs = [
      [
        func: :render,
        code: code,
        doc: doc,
        line: line,
        assert: assert
      ]
    ]

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
          {:module, _mod} -> nil
          {:error, _} ->
            message =
              "defined catalogue `#{inspect(module)}` could not be found"
              Surface.IOHelper.compile_error(message, env.file,  Module.get_attribute(env.module, :__use_line__))
        end
    end
  end

  def __on_definition__(env, :def, :render, [_arg], _guards, _body) do
    Module.put_attribute(env.module, :__example_line__, env.line)
  end

  def __on_definition__(_env, _kind, _name, _args, _guards, _body) do
    :ok
  end
end
