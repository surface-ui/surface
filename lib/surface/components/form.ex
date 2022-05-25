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

  import Surface.Components.Utils, only: [opts_to_phx_opts: 1]
  import Surface.Components.Form.Utils, only: [props_to_opts: 2, props_to_attr_opts: 2]

  @doc """
  The ID of the form attribute.
  If an ID is given, all form inputs will also be prefixed by the given ID.
  Required to enable form recovery following crashes or disconnects.
  """
  prop id, :string

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

  @doc """
  Trigger a standard form submit on DOM patch to the URL specified in the form's standard action
  attribute.
  This is useful to perform pre-final validation of a LiveView form submit before posting to a
  controller route for operations that require Plug session mutation.
  """
  prop trigger_action, :boolean

  @doc "Keyword list of errors for the form."
  prop errors, :keyword

  @doc "Keyword list with options to be passed down to `Phoenix.HTML.Tag.tag/2`"
  prop opts, :keyword, default: []

  @doc "Class or classes to apply to the form"
  prop class, :css_class

  @doc "Triggered when the form is changed"
  prop change, :event

  @doc "Triggered when the form is submitted"
  prop submit, :event

  @doc """
  Triggered when the form is being recovered.
  Use this event to enable specialized recovery when extra recovery handling
  on the server is required.
  """
  prop auto_recover, :event

  @doc "The content of the `<form>`"
  slot default, args: [:form]

  def render(assigns) do
    attr_opts = props_to_attr_opts(assigns, class: get_config(:default_class))

    form_opts =
      assigns
      |> props_to_opts([:as, :method, :multipart, :csrf_token, :errors, :trigger_action])
      |> opts_to_phx_opts()

    event_opts =
      event_to_opts(assigns.change, :phx_change) ++
        event_to_opts(assigns.submit, :phx_submit) ++
        event_to_opts(assigns.auto_recover, :phx_auto_recover)

    opts =
      assigns.opts
      |> Keyword.merge(attr_opts)
      |> Keyword.merge(form_opts)
      |> Keyword.merge(event_opts)

    assigns = assign(assigns, opts: opts)

    ~F"""
    <.form :let={form} for={@for} action={@action} {...@opts}>
      <Context put={__MODULE__, form: form}>
        <#slot :args={form: form} />
      </Context>
    </.form>
    """
  end
end
