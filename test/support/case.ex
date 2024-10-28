defmodule Surface.Case do
  @moduledoc """
  This module defines a generic test case importing common funcions for tests.
  """

  use ExUnit.CaseTemplate

  using do
    quote do
      import ANSIHelpers
    end
  end
end
