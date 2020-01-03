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
      use Surface.BaseComponent
      use Surface.EventValidator
      import Phoenix.HTML

      property id, :integer
      property session, :map

      def translator do
        Surface.Translator.LiveViewTranslator
      end

      use Phoenix.LiveView
    end
  end
end
