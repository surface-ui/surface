defmodule Mix.Tasks.Compile.Surface.DefinitionsTest.PhoenixComponents do
  use Phoenix.Component

  attr(:name, :string, doc: "Docs for func_with_attr/1")
  def phoenix_func_with_attr(assigns), do: ~H[]

  def phoenix_func_without_attr(assigns), do: ~H[]
end
