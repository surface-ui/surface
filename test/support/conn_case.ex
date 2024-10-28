defmodule Surface.ConnCase do
  @moduledoc """
  This module defines the test case to be used by
  tests that require setting up a connection.

  It also imports other functionality to make it easier
  to test components.
  """

  use ExUnit.CaseTemplate

  using do
    quote do
      # Import conveniences for testing
      use Surface.LiveViewTest
      import Floki
      import FlokiHelpers
      import ANSIHelpers

      # The default endpoint for testing
      @endpoint Endpoint
    end
  end

  setup _tags do
    {:ok, conn: Phoenix.ConnTest.build_conn()}
  end
end
