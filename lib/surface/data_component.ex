defmodule Surface.DataComponent do
  defmacro __using__(opts \\ []) do
    group = Keyword.get(opts, :group, __CALLER__.module)

    quote do
      use Surface.Properties

      import unquote(__MODULE__)
      @behaviour unquote(__MODULE__)

      def data(assigns) do
        {:ok, assigns}
      end

      def __group__ do
        unquote(group)
      end

      defoverridable data: 1
    end
  end

  @callback data(assigns :: map()) :: {:ok, any}
end
