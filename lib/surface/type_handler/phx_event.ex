defmodule Surface.TypeHandler.PhxEvent do
  @moduledoc false

  use Surface.TypeHandler

  alias Surface.IOHelper

  @impl true
  def value_to_html(_name, value) when is_binary(value) or is_nil(value) do
    value
  end

  def value_to_html(name, value) do
    IOHelper.runtime_error(
      "invalid value for \"#{name}\". LiveView bindings only accept values " <>
        "of type :string. If you want to pass an :event, please use directive " <>
        ":on-#{name} instead. Expected a :string, got: #{inspect(value)}"
    )
  end
end
