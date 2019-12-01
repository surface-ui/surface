defmodule Surface.BaseComponent do
  @callback translator() :: module

  defmacro __using__(_) do
    quote do
      use Surface.Properties
      import Surface
      @behaviour unquote(__MODULE__)
    end
  end
end
