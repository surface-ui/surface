defmodule Surface.Components.Form do
  @moduledoc """
  Defines a **form** that lets the user submit information.

  Provides a wrapper for `Phoenix.HTML.Form.form_for/3`. Additionally,
  adds the form instance that is returned by `form_for/3` into the context,
  making it available to any child input.

  All options passed via `opts` will be sent to `form_for/3`, `for`
  and `action` can be set directly and will override anything in `opts`.

  """

  use Surface.Component

  import Phoenix.HTML.Form
  import Surface.Components.Form.Utils, only: [props_to_opts: 2]
  alias Surface.Components.Raw

  @doc "Atom or changeset to inform the form data"
  prop for, :any, required: true

  @doc "URL to where the form is submitted"
  prop action, :string, default: "#"

  @doc "The server side parameter in which all parameters will be gathered."
  prop as, :atom

  @doc "Method to be used when submitting the form."
  prop method, :string

  @doc "When true, sets enctype to \"multipart/form-data\". Required when uploading files."
  prop multipart, :boolean, default: false

  @doc """
  For \"post\" requests, the form tag will automatically include an input
  tag with name _csrf_token. When set to false, this is disabled.
  """
  prop csrf_token, :any

  @doc "Keyword list of errors for the form."
  prop errors, :keyword

  @doc "Keyword list with options to be passed down to `Phoenix.HTML.Tag.tag/2`"
  prop opts, :keyword, default: []

  @doc "Triggered when the form is changed"
  prop change, :event

  @doc "Triggered when the form is submitted"
  prop submit, :event

  @doc "The content of the `<form>`"
  slot default, props: [:form]

  def render(assigns) do
    ~H"""
    {{ form = form_for(@for, @action, get_opts(assigns)) }}
      <Context put={{ __MODULE__, form: form }}>
        <slot :props={{ form: form }} />
      </Context>
    <#Raw></form></#Raw>
    """
  end

  defp get_opts(assigns) do
    form_opts = props_to_opts(assigns, [:as, :method, :multipart, :csrf_token, :errors])

    form_opts ++
      assigns.opts ++
      event_to_opts(assigns.change, :phx_change) ++
      event_to_opts(assigns.submit, :phx_submit)
  end
end
