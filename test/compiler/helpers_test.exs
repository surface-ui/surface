defmodule Surface.Compiler.HelpersTest do
  use ExUnit.Case

  alias Surface.Compiler.Helpers

  describe "used_assigns" do
    test "detects all assigns referenced via @assign_name" do
      assigns =
        quote do
          value = @something + @something_else
          Enum.map(@list, fn value -> value end)
        end
        |> Helpers.used_assigns()
        |> Keyword.keys()

      assert [:something, :something_else, :list] = assigns
    end

    test "returns empty list when no assigns referenced via @assign_name" do
      assigns =
        quote do
          the_value + 1
        end
        |> Helpers.used_assigns()
        |> Keyword.keys()

      assert [] = assigns
    end

    test "returns empty list when assigns only referenced by dot-notation" do
      assigns =
        quote do
          value = assigns.something + assigns.something_else
          Enum.map(assigns.list, fn value -> value end)
        end
        |> Helpers.used_assigns()
        |> Keyword.keys()

      assert [] = assigns
    end
  end
end
