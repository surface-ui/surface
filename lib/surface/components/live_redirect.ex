defmodule Surface.Components.LiveRedirect do
  @moduledoc """
  > #### Deprecation warning {: .warning}
  >
  > This component has been deprecated in favor of liveview's built-in `<.link>`
  > and will be removed in `v0.13`. See https://hexdocs.pm/phoenix_live_view/live-navigation.html for
  > more info and usage.

  Defines a link that will **redirect** to a new LiveView.

  Provides similar capabilities to Phoenix's built-in `live_redirect/2`
  function.

  The current LiveView will be shut down and a new one will be mounted
  in its place, without reloading the whole page. This can
  also be used to remount the same LiveView, in case you want to start
  fresh. If you want to navigate to the same LiveView without remounting
  it, use `<LivePatch>` instead.
  """

  @moduledoc deprecated: "Use liveview's built-in `<.link>` instead"

  use Surface.Component

  @doc "The required path to link to"
  prop to, :string, required: true

  @doc "The flag to replace the current history or push a new state"
  prop replace, :boolean, default: false

  @doc "The CSS class for the generated `<a>` element"
  prop class, :css_class, default: ""

  @doc """
  The label for the generated `<a>` element, if no content (default slot) is provided.
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

  if Mix.env() != :test do
    @deprecated "Use liveview's built-in `<.link>` instead"
  end

  def render(assigns) do
    ~F"""
    <a
      href={@to}
      class={@class}
      data-phx-link="redirect"
      data-phx-link-state={if @replace, do: "replace", else: "push"}
      :attrs={@opts}
    ><#slot>{@label}</#slot></a>
    """
  end
end
