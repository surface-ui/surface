defmodule Surface.LiveView do
  @moduledoc """
  A wrapper component around `Phoenix.LiveView`.

  Since this module is just a wrapper around `Phoenix.LiveView`, you
  cannot define custom properties for it. Only `:id` and `:session`
  are available. However, built-in directives like `:for` and `:if`
  can be used normally.

  ## Example

      defmodule Example do
        use Surface.LiveView

        def render(assigns) do
          ~H"\""
          <Dialog title="Alert" id="dialog">
            This <b>Dialog</b> is a stateful component. Cool!
          </Dialog>

          <Button click="show_dialog">Click to open the dialog</Button>
          "\""
        end

        def handle_event("show_dialog", _, socket) do
          Dialog.show("dialog")
          {:noreply, socket}
        end
      end

  """

  defmacro __using__(_) do
    quote do
      use Surface.BaseComponent, translator: Surface.Translator.LiveViewTranslator
      use Surface.API, include: [:property, :data]
      use Surface.EventValidator
      import Phoenix.HTML

      @doc "The id of the live view"
      property id, :integer

      @doc """
      The request info necessary for the view, such as params, cookie session info, etc.
      The session is signed and stored on the client, then provided back to the server
      when the client connects, or reconnects to the stateful view.
      """
      property session, :map

      use Phoenix.LiveView
    end
  end
end
