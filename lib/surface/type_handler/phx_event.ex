defmodule Surface.TypeHandler.PhxEvent do
  @moduledoc false

  use Surface.TypeHandler

  @impl true
  def value_to_html(_name, value) when is_binary(value) or is_nil(value) do
    {:ok, value}
  end

  def value_to_html(name, value) do
    "phx-" <> event = to_string(name)

    message = """
    invalid value for "#{name}". LiveView bindings only accept values \
    of type :string. If you want to pass an :event, please use directive \
    :on-#{event} instead. Expected a :string, got: #{inspect(value)}\
    """

    {:error, message}
  end
end
