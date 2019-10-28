defmodule Surface.DataComponent do
  defmacro __using__(_) do
    quote do
      use Surface.BaseComponent
      use Surface.Binding

      import unquote(__MODULE__)
      @behaviour unquote(__MODULE__)

      defdelegate render_code(mod_str, attributes, children_iolist, mod, caller),
        to: Surface.DataComponentRenderer

      def init(assigns) do
        {:ok, assigns}
      end

      defoverridable render_code: 5, init: 1
    end
  end

  @callback begin_context(props :: map()) :: map()
  @callback end_context(props :: map()) :: map()
  @callback init(assigns :: map()) :: {:ok, any}

  @optional_callbacks begin_context: 1, end_context: 1
end
