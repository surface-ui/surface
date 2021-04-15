defmodule Surface.Components.Events do
  @moduledoc false

  defmacro __using__(_) do
    quote do
      @doc "Triggered when the page loses focus"
      prop window_blur, :event

      @doc "Triggered when the page receives focus"
      prop window_focus, :event

      @doc "Triggered when the component loses focus"
      prop blur, :event

      @doc "Triggered when the component receives focus"
      prop focus, :event

      @doc "Triggered when the component captures click"
      prop capture_click, :event

      @doc "Triggered when the component receives click"
      prop click, :event

      @doc "Triggered when a button on the keyboard is pressed"
      prop keydown, :event

      @doc "Triggered when a button on the keyboard is released"
      prop keyup, :event
    end
  end
end
