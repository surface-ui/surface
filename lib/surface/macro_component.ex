defmodule Surface.MacroComponent do
  @moduledoc """
  A low-level component which is responsible for translating its own
  content at compile time.
  """

  defmacro __using__(_) do
    quote do
      use Surface.BaseComponent, translator: __MODULE__

      @behaviour Surface.Translator
    end
  end

  @doc """
  Tranlates the content of the macro component.
  """
  @callback translate(code :: any, caller: Macro.Env.t()) ::
    {open :: iodata(), content :: iodata(), close :: iodata()}
end
