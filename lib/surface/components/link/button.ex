defmodule Surface.Components.Link.Button do
  @moduledoc """
  Generates a button that uses a regular HTML form to submit to the given URL.

  Useful to ensure that links that change data are not triggered by search engines and other spidering software.

  Provides similar capabilities to Phoenix's built-in `button/2` function.

  Options `label` and `class` can be set directly and will override anything in `opts`.
  All other options are forwarded to the underlying <button> tag.

  ## Examples
  ```
  <Button
    label="user"
    to="/users/1"
    class="is-danger"
    method={{ :delete }}
    opts={{ data: [confirm: "Really?"] }}
  />

  <Button
    to="/users/1"
    class="is-link"
  >
    <span>user</span>
  </Button>
  ```
  """

  use Surface.Component
  use Surface.Components.Events

  import Surface.Components.Utils

  @doc "The page to link to"
  prop to, :any, required: true

  @doc "The method to use with the button"
  prop method, :atom, default: :post

  @doc "Id to apply to the button"
  prop id, :string

  @doc "Class or classes to apply to the button"
  prop class, :css_class

  @doc """
  The label for the generated `<button>` element, if no content (default slot) is provided.
  """
  prop label, :string

  @doc """
  Additional attributes to add onto the generated element
  """
  prop opts, :keyword, default: []

  @doc """
  The content of the generated `<button>` element. If no content is provided,
  the value of property `label` is used instead.
  """
  slot default

  def render(assigns) do
    unless assigns[:default] || assigns[:label] || Keyword.get(assigns.opts, :label) do
      raise ArgumentError, "<Button /> requires a label prop or contents in the default slot"
    end

    to = valid_destination!(assigns.to, "<Button />")
    events = events_to_opts(assigns)
    opts = link_method(assigns.method, to, assigns.opts)
    assigns = assign(assigns, to: to, opts: events ++ opts)

    ~F"""
    <button id={@id} class={@class} :attrs={@opts}><#slot>{@label}</#slot></button>
    """
  end

  defp link_method(method, to, opts) do
    data =
      opts
      |> Keyword.get(:data, [])
      |> Keyword.merge(method: method, to: to)

    if method == :get do
      opts
      |> skip_csrf()
      |> Keyword.merge(data: data)
    else
      {csrf_data, opts} = csrf_data(to, opts)

      data =
        opts
        |> Keyword.get(:data, [])
        |> Keyword.merge(csrf_data)
        |> Keyword.merge(method: method, to: to)

      Keyword.merge(opts, data: data)
    end
  end
end
