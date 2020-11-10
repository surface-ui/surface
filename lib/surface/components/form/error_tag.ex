defmodule Surface.Components.Form.ErrorTag do
  @moduledoc """
  An error tag inspired by `error_tag/3` that ships with `mix phx.new`
  in `MyAppWeb.ErrorHelpers`.

  Renders error messages if there are any about the given field.

  ## Examples

  ```
  <ErrorTag field="password" />
  ```
  """

  use Surface.Components.Form.Input
  use Phoenix.HTML

  @doc """
  If you changed the default ID on the input, provide it here.
  (Useful when there are multiple forms on the same page, each
  with an input of the same name. LiveView will exhibit buggy behavior
  without assigning separate id's to each.)
  """
  prop phx_feedback_for, :string

  def render(assigns) do
    # In the context of <Form form={{ :some_atom }}>, `form` will be `nil` here,
    # causing it to crash. So just render nothing instead.
    # (There wouldn't have been errors to show anyways since there's no Changeset.)
    ~H"""
    <InputContext assigns={{ assigns }} :let={{ form: form, field: field }}>
      <span
        :if={{ not is_nil(form) }}
        :for={{ error <- Keyword.get_values(form.errors, field) }}
        class={{ @class }}
        phx-feedback-for={{ @phx_feedback_for || input_id(form, field) }}
      >{{ translate_error(error) }}</span>
    </InputContext>
    """
  end

  @doc """
  Borrowed from `mix phx.new` generated translate_error/1.

  Translates an error message using gettext.
  """
  def translate_error({msg, opts}) do
    gettext_module = Application.get_env(:surface, :gettext_module)

    unless gettext_module do
      raise """
      Please define a gettext module in config in order to use <ErrorTag>:

      config :surface, gettext_module: MyAppWeb.Gettext
      """
    end

    # When using gettext, we typically pass the strings we want
    # to translate as a static argument:
    #
    #     # Translate "is invalid" in the "errors" domain
    #     dgettext("errors", "is invalid")
    #
    #     # Translate the number of files with plural rules
    #     dngettext("errors", "1 file", "%{count} files", count)
    #
    # Because the error messages we show in our forms and APIs
    # are defined inside Ecto, we need to translate them dynamically.
    # This requires us to call the Gettext module passing our gettext
    # backend as first argument.
    #
    # Note we use the "errors" domain, which means translations
    # should be written to the errors.po file. The :count option is
    # set by Ecto and indicates we should also apply plural rules.
    if count = opts[:count] do
      Gettext.dngettext(gettext_module, "errors", msg, msg, count, opts)
    else
      Gettext.dgettext(gettext_module, "errors", msg, opts)
    end
  end
end
