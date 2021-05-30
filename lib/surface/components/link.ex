defmodule Surface.Components.Link do
  @moduledoc """
  Generates a link to the given URL.

  Provides similar capabilities to Phoenix's built-in `link/2` function.

  Options `label` and `class` can be set directly and will override anything in `opts`.
  All other options are forwarded to the underlying <a> tag.

  ## Examples
  ```
  <Link
    label="user"
    to="/users/1"
    class="is-danger"
    method={{ :delete }}
    opts={{ data: [confirm: "Really?"] }}
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
  use Surface.Components.Events

  import Surface.Components.Utils

  @doc "The page to link to"
  prop to, :any, required: true

  @doc "The method to use with the link"
  prop method, :atom, default: :get

  @doc "Id to apply to the link"
  prop id, :string

  @doc "Class or classes to apply to the link"
  prop class, :css_class

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

  def update(assigns, socket) do
    valid_label!(assigns)
    {:ok, assign(socket, assigns)}
  end

  def render(assigns) do
    to = valid_destination!(assigns.to, "<Link />")
    opts = apply_method(to, assigns.method, assigns.opts) ++ events_to_opts(assigns)
    attrs = opts_to_attrs(opts)

    ~H"""
    <a id={@id} class={@class} href={to} :attrs={attrs}><#slot>{@label}</#slot></a>
    """
  end

  defp valid_label!(assigns) do
    unless assigns[:default] || assigns[:label] || Keyword.get(assigns.opts, :label) do
      raise ArgumentError, "<Link /> requires a label prop or contents in the default slot"
    end
  end

  defp apply_method(to, method, opts) do
    if method == :get do
      skip_csrf(opts)
    else
      {csrf_data, opts} = csrf_data(to, opts)
      opts = Keyword.put_new(opts, :rel, "nofollow")
      [data: [method: method, to: to] ++ csrf_data] ++ opts
    end
  end
end
