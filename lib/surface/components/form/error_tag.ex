defmodule Surface.Components.Form.ErrorTag do
  @moduledoc """
  An error tag inspired by `error_tag/3` that ships with `mix phx.new`
  in `MyAppWeb.ErrorHelpers`.

  Renders error messages if there are any about the given field.

  ## Examples

  ```surface
  <ErrorTag field="password" />
  ```
  """

  use Surface.Component

  import Phoenix.HTML.Form, only: [input_id: 2]

  alias Surface.Components.Form.Input.InputContext

  @doc "An identifier for the form"
  prop form, :form

  @doc "An identifier for the associated field"
  prop field, :atom

  @doc "Class or classes to apply to each error tag <span>"
  prop class, :css_class

  @doc """
  A function that takes one argument `{msg, opts}` and returns
  the translated error message as a string. If not provided, falls
  back to Phoenix's default implementation.

  This can also be set via config, for example:

  ```elixir
  config :surface, :components, [
    {Surface.Components.Form.ErrorTag, translator: {MyApp.Gettext, :translate_error}}
  ]
  ```
  """
  prop translator, :fun

  @doc """
  If you changed the default ID on the input, provide it here.
  (Useful when there are multiple forms on the same page, each
  with an input of the same name. LiveView will exhibit buggy behavior
  without assigning separate id's to each.)
  """
  prop phx_feedback_for, :string

  def render(assigns) do
    translate_error = assigns.translator || translator_from_config() || (&translate_error/1)

    ~H"""
    <InputContext assigns={{ assigns }} :let={{ form: form, field: field }}>
      <span
        :for={{ error <- Keyword.get_values(form.errors, field) }}
        class={{ @class }}
        phx-feedback-for={{ @phx_feedback_for || input_id(form, field) }}
      >{{ translate_error.(error) }}</span>
    </InputContext>
    """
  end

  @doc """
  Translates an error message.

  This is the fallback (Phoenix's default implementation) if a translator
  is not provided via config or the `translate` prop.
  """
  def translate_error({msg, opts}) do
    # Because the error messages we show in our forms and APIs
    # are defined inside Ecto, we need to translate them dynamically.
    Enum.reduce(opts, msg, fn {key, value}, acc ->
      String.replace(acc, "%{#{key}}", to_string(value))
    end)
  end

  defp translator_from_config do
    if translator = get_config(:translator) do
      {module, function} = translator
      &apply(module, function, [&1])
    end
  end
end
