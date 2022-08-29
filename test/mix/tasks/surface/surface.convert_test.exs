defmodule Surface.Mix.Tasks.ConvertTest do
  use ExUnit.Case

  import ExUnit.CaptureIO

  describe "reads from stdin and prints to stdout with converter" do
    test "handles an Elixir file" do
      file = ~S[
      defmodule Card do
        use Surface.Component

        def render(assigns) do
          ~F"""
            <#template></#template>
          """
        end
      end
      ]

      converted = ~S[
      defmodule Card do
        use Surface.Component

        def render(assigns) do
          ~F"""
            <:default></:default>
          """
        end
      end
      ]

      assert converted ==
               capture_io(file, fn ->
                 Mix.Tasks.Surface.Convert.run(["-"])
               end)
    end

    test "handles an Elixir file with ~H without errors and without conversion" do
      file = ~S[
      defmodule Card do
        use Surface.Component

        def render(assigns) do
          ~H"""
            <%= flash %>
            <#template></#template>
          """
        end
      end
      ]

      converted = ~S[
      defmodule Card do
        use Surface.Component

        def render(assigns) do
          ~H"""
            <%= flash %>
            <#template></#template>
          """
        end
      end
      ]

      assert converted ==
               capture_io(file, fn ->
                 Mix.Tasks.Surface.Convert.run(["-"])
               end)
    end

    test "handles a Surface file" do
      file = "<#template>Footer</#template>\n"
      converted = "<:default>Footer</:default>\n"

      assert converted ==
               capture_io(file, fn ->
                 Mix.Tasks.Surface.Convert.run(["-"])
               end)
    end
  end
end
