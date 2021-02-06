defmodule Surface.Components.Link do
  @moduledoc """
  Generates a link to the given URL.

  Provides similar capabilities to Phoenix's built-in `link/2`
  function.

  Options `label` and `class` can be set directly and will override anything in `opts`.
  All other options are forwarded to the underlying <a> tag.

  ## Examples
  ```
  <Link
    label="user"
    to="/users/1"
    class="is-danger"
    opts={{ method: :delete, data: [confirm: "Really?"] }}
  />

  <Link
    to="/users/1"
    class="is-link"
  >
    <span>user</span>
  </Link>
  ```
  """

  use Surface.Component

  @doc "The page to link to"
  prop to, :string, required: true

  @doc "The method to use with the link"
  prop method, :atom, default: :get

  @doc "Class or classes to apply to the link"
  prop class, :css_class

  @doc """
  The label for the generated `<a>` alement, if no content (default slot) is provided.
  """
  prop label, :string

  @doc "Triggered on click"
  prop click, :event

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
      href={{ @to }}
      :attrs={{ @opts ++ event_to_opts(@click, :phx_click) |> opts_to_attrs(assigns) }}
    ><slot>{{ @label }}</slot></a>
    """
  end

  defp opts_to_attrs(opts, assigns) do
    for {key, value} <- opts do
      case key do
        :csrf_token -> {:"data-csrf", value}
        :phx_click -> {:"phx-click", value}
        :phx_target -> {:"phx-target", value}
        :method -> method_to_attrs(value, assigns.to)
        :data -> data_to_attrs(value)
        _ -> {key, value}
      end
    end
    |> List.flatten()
  end

  defp method_to_attrs(method, to) do
    case method do
      :get -> []
      _ -> ["data-method": method, "data-to": to, rel: "nofollow"]
    end
  end

  defp data_to_attrs(data) when is_list(data) do
    for {key, value} <- data do
      {:"data-#{key}", value}
    end
  end
end
