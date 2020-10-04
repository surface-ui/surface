defmodule Surface.Components.LivePatch do
  @moduledoc """
  Defines a link that will **patch** the current LiveView.

  Provides similar capabilities to Phoenix's built-in `live_patch/2`
  function.

  When navigating to the current LiveView, `handle_params/3` is
  immediately invoked to handle the change of params and URL state.
  Then the new state is pushed to the client, without reloading the
  whole page. For live redirects to another LiveView, use
  `<LiveRedirect>` instead.
  """

  use Surface.Component

  @doc "The required path to link to"
  prop to, :string, required: true

  @doc "The flag to replace the current history or push a new state"
  prop replace, :boolean, default: false

  @doc "The CSS class for the generated `<a>` element"
  prop class, :css_class, default: ""

  @doc """
  The label for the generated `<a>` alement, if no content (default slot) is provided.
  """
  prop label, :string

  @doc """
  Additional attributes to add onto the generated element
  """
  prop opts, :keyword, default: []

  @doc """
  The content of the generated `<a>` element. If no content is provided,
  the value of property `label` is used instead.
  """
  slot default

  def render(assigns) do
    ~H"""
    <a
      class={{ @class }}
      data-phx-link="patch"
      data-phx-link-state={{ if @replace, do: "replace", else: "push" }}
      href={{ @to }}
      :attrs={{ @opts }}
    ><slot>{{ @label }}</slot></a>
    """
  end
end
