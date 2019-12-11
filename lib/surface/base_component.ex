defmodule Surface.BaseComponent do
  @moduledoc !"""
  This module defines the basic behaviour to be implemented by each
  different type of component.
  """

  @doc """
  Defines which module is responsible for translating the component. The
  returned module must implement the `Surface.Translator` behaviour.
  """
  @callback translator() :: module

  defmacro __using__(_) do
    quote do
      use Surface.Properties
      import Surface
      @behaviour unquote(__MODULE__)
    end
  end
end
