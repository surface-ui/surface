defmodule Surface do
  @moduledoc """
  Surface is component based library for **Phoenix LiveView**.

  Built on top of the new `Phoenix.LiveComponent` API, Surface provides
  a more declarative way to express and use components in Phoenix.

  A work-in-progress live demo with more details can be found at [surface-demo.msaraiva.io](http://surface-demo.msaraiva.io)

  This module defines the `~H` sigil that should be used to translate Surface
  code into Phoenix templates.

  In order to have `~H` available for any Phoenix view, add the following import to your web
  file in `lib/my_app_web.ex`:

      # lib/my_app_web.ex

      ...

      def view do
        quote do
          ...
          import Surface
        end
      end

  ## Defining components

  To create a component you need to define a module and `use` one of the available component types:

    * `Surface.Component` - A functional (stateless) component.
    * `Surface.LiveComponent` - A live (stateless or stateful) component. A wrapper around `Phoenix.LiveComponent`.
    * `Surface.LiveView` - A wrapper component around `Phoenix.LiveView`.
    * `Surface.DataComponent` - A component that serves as a customizable data holder for the parent component.
    * `Surface.MacroComponent` - A low-level component which is responsible for translating its own content at compile time.

  ### Example

      # A functional stateless component

      defmodule Button do
        use Surface.Component

        property click, :event
        property kind, :string, default: "is-info"

        def render(assigns) do
          ~H"\""
          <button class="button {{ @kind }}" phx-click={{ @click }}>
            {{ @content.() }}
          </button>
          "\""
        end
      end

  You can visit the documentation of each type of component for further explanation and examples.

  ## Directives

  Directives are built-in attributes that can modify the translated code of a component
  at compile time. Currently, the following directives are supported:

    * `:for` - Iterates over a list (generator) and renders the content of the tag (or component)
      for each item in the list.

    * `:if` - Conditionally render a tag (or component). The code will be rendered if the expression
      is evaluated to a truthy value.

    * `:bindings` - Defines the name of the variables (bindings) in the current scope that represent
      the values passed internally by the component when calling the `@content` function.

  ### Example

      <div>
        <div class="header" :if={{ @showHeader }}>
          The Header
        </div>
        <ul>
          <li :for={{ item <- @items }}>
            {{ item }}
          </li>
        </ul>
      </div>
  """

  @doc """
  Translates Surface code into Phoenix templates.
  """
  defmacro sigil_H({:<<>>, _, [string]}, _) do
    line_offset = __CALLER__.line + 1
    string
    |> Surface.Translator.run(line_offset, __CALLER__, __CALLER__.file)
    |> EEx.compile_string(engine: Phoenix.LiveView.Engine, line: line_offset, file: __CALLER__.file)
  end

  @doc false
  def component(module, assigns) do
    module.render(assigns)
  end

  @doc false
  def component(module, assigns, []) do
    module.render(assigns)
  end

  @doc false
  def put_default_props(props, mod) do
    Enum.reduce(mod.__props__(), props, fn %{name: name, default: default}, acc ->
      Map.put_new(acc, name, default)
    end)
  end

  @doc false
  def css_class(list) when is_list(list) do
    Enum.reduce(list, [], fn item, classes ->
      case item do
        {class, true} ->
          [to_kebab_case(class) | classes]
        class when is_binary(class) or is_atom(class) ->
          [to_kebab_case(class) | classes]
        _ ->
          classes
      end
    end) |> Enum.reverse() |> Enum.join(" ")
  end

  @doc false
  def css_class(value) when is_binary(value) do
    value
  end

  # TODO: Find a better way to do this
  defp to_kebab_case(value) do
    value
    |> to_string()
    |> Macro.underscore()
    |> String.replace("_", "-")
  end
end
