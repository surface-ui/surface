defmodule Surface.Components.Form.OptionsForSelect do
  @moduledoc """
  Defines options to be used inside a select.

  This is useful when building the select by hand.

  Provides a wrapper for Phoenix.HTML.Form's `options_for_select/2` function.
  """

  use Surface.Component

  import Phoenix.HTML.Form, only: [options_for_select: 2]

  @doc "The options in the select"
  prop options, :any, default: []

  @doc "The selected values"
  prop selected, :any, default: nil

  def render(assigns) do
    ~H"""
    {{ options_for_select(@options, @selected) }}
    """
  end
end
