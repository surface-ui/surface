defmodule Surface.DataComponent do
  @moduledoc """
  Defines a component that serves as a customizable data holder for the
  parent component.

  ## Example

      defmodule Column do
        use Surface.DataComponent

        property title, :string
        property field, :string
      end

  As you can see, data components don't need to implement a `render/1` callback.
  Instead, this module defines a `c:data/1` callback that you can use to
  transform, filter or validate properties before sending them to the parent
  component. By default all properties are sent as they were originally defined.
  """

  defmacro __using__(opts \\ []) do
    slot_name = Keyword.get(opts, :name)

    if !slot_name do
      message = "slot name is required. Usage: use Surface.DataComponent, name: \"...\""
      raise %CompileError{line: __CALLER__.line, file: __CALLER__.file, description: message}
    end

    quote do
      use Surface.BaseComponent, translator: Surface.Translator.DataComponentTranslator
      use Surface.API, include: [:property]
      import unquote(__MODULE__)

      @behaviour unquote(__MODULE__)

      def data(assigns) do
        {:ok, assigns}
      end

      def __slot_name__ do
        unquote(String.to_atom(slot_name))
      end

      defoverridable data: 1
    end
  end

  @doc """
  Implement this callback in order to transform, filter or validate
  properties before sending them to the parent component.
  """
  @callback data(assigns :: map()) :: {:ok, any}

  @doc """
  This optional callback is invoked in order to set up a
  context that can be retrieved for any descendent component.
  """
  @callback init_context(props :: map()) :: map()

  @optional_callbacks init_context: 1
end
