defmodule Surface.CheckUpdated do
  use Surface.LiveComponent

  @doc "The process to send the :updated message"
  prop dest, :pid, required: true

  @doc "Something to inspect"
  prop content, :any, default: %{}

  def update(assigns, socket) do
    if connected?(socket) do
      send(assigns.dest, {:updated, assigns.id})
    end

    {:ok, assign(socket, assigns)}
  end

  def render(assigns) do
    ~F"""
    <div>{inspect(@content)}</div>
    """
  end
end
