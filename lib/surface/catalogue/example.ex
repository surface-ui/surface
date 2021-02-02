defmodule Surface.Catalogue.Example do
  @moduledoc """
  Experimental LiveView to create examples for catalogue tools.

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

  """

  defmacro __using__(opts) do
    subject = Surface.Catalogue.fetch_subject!(opts, __MODULE__, __CALLER__)

    quote do
      use Surface.LiveView, unquote(opts)

      alias unquote(subject)
      require Surface.Catalogue.Data, as: Data

      @config unquote(opts)
      @before_compile unquote(__MODULE__)

      import Surface, except: [sigil_H: 2]

      defmacrop sigil_H({:<<>>, meta, [string]} = ast, opts) do
        Module.put_attribute(__CALLER__.module, :code, string)

        quote do
          Surface.sigil_H(unquote(ast), unquote(opts))
        end
      end
    end
  end

  defmacro __before_compile__(env) do
    config = Module.get_attribute(env.module, :config)
    subject = Keyword.fetch!(config, :subject)
    code = Module.get_attribute(env.module, :code)

    quote do
      @moduledoc catalogue: [
                   type: :example,
                   subject: unquote(subject),
                   config: unquote(config),
                   code: unquote(code)
                 ]
    end
  end
end
