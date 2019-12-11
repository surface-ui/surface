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
  component. By default all properties are sent as they were originaly defined.
  """

  defmacro __using__(opts \\ []) do
    group = Keyword.get(opts, :group, __CALLER__.module)

    quote do
      use Surface.BaseComponent
      import unquote(__MODULE__)

      @behaviour unquote(__MODULE__)

      def translator do
        Surface.Translator.DataComponentTranslator
      end

      def data(assigns) do
        {:ok, assigns}
      end

      def __group__ do
        unquote(group)
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
  @callback begin_context(props :: map()) :: map()

  @doc """
  This optional callback is invoked in order to clean up a
  context previously created in the `c:begin_context/1`.
  """
  @callback end_context(props :: map()) :: map()

  @optional_callbacks begin_context: 1, end_context: 1
end
