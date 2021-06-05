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
    valid_label!(assigns)
    to = valid_destination!(assigns.to, "<Button />")

    ~F"""
    <button id={@id} class={@class} :attrs={to_attrs(assigns, to)}><#slot>{@label}</#slot></button>
    """
  end

  defp valid_label!(assigns) do
    unless assigns[:default] || assigns[:label] || Keyword.get(assigns.opts, :label) do
      raise ArgumentError, "<Button /> requires a label prop or contents in the default slot"
    end
  end

  defp apply_method(to, method, opts) do
    if method == :get do
      opts = skip_csrf(opts)
      [data: [method: method, to: to]] ++ opts
    else
      {csrf_data, opts} = csrf_data(to, opts)
      [data: [method: method, to: to] ++ csrf_data] ++ opts
    end
  end

  def to_attrs(assigns, to) do
    (apply_method(to, assigns.method, assigns.opts) ++ events_to_opts(assigns))
    |> opts_to_attrs()
  end
end
