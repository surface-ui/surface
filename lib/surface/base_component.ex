defmodule Surface.BaseComponent do
  defmacro __using__(_) do
    quote do
      use Surface.Properties
      import Phoenix.HTML
    end
  end
end
