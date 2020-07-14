defmodule Surface.Style.Processor do
  @moduledoc """
  A behaviour for defining style processors.

  The style processor receives a list of options and the body (block)
  defined by the `style` built-in macro and processes it.

  The resulting CSS should be split into a static part and a `EEX`
  template that renders the dynamic part.
  """

  @type static_css :: binary | nil
  @type dynamic_css_template :: binary | nil
  @type error :: {:error, message :: String.t(), line :: non_neg_integer}

  @callback normalize_block(block :: Macro.t()) :: Macro.t()

  @callback normalize_opts(opts :: Macro.t()) :: Macro.t()

  @doc """
  Process the style block generating static and dynamic CSS.
  """
  @callback process(code :: Macro.t(), opts :: keyword, caller :: Macro.Env.t()) ::
              {:ok, static_css, dynamic_css_template} | error()
end
