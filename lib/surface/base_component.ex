defmodule Surface.BaseComponent do

  @callback translator() :: module

  defmacro __using__(_) do
    quote do
      use Surface.Properties

      import unquote(__MODULE__)
      @behaviour unquote(__MODULE__)

      import Phoenix.HTML
    end
  end
end
