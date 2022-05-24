defmodule Surface.LiveViewTestTest.DisableTests do
  # Overrides __ex_unit__/0 so the tests don't actually run.
  # If we don't do this tests will run twice.
  defmacro __before_compile__(_env) do
    quote do
      defoverridable __ex_unit__: 0

      def __ex_unit__() do
        %ExUnit.TestModule{super() | tests: []}
      end
    end
  end
end

defmodule Surface.LiveViewTestTest.PassingCatalogueSubjectTests do
  use Surface.ConnCase, async: true
  @before_compile Surface.LiveViewTestTest.DisableTests

  catalogue_test Surface.LiveViewTestTest.FakeComponent
end

defmodule Surface.LiveViewTestTest.PassingCatalogueAllTests do
  use Surface.ConnCase, async: true
  @before_compile Surface.LiveViewTestTest.DisableTests

  catalogue_test :all
end

defmodule Surface.LiveViewTestTest.PassingCatalogueAllAndExceptTests do
  use Surface.ConnCase, async: true
  @before_compile Surface.LiveViewTestTest.DisableTests

  catalogue_test(:all, except: [Surface.LiveViewTestTest.OtherFakeComponent])
end

defmodule Surface.LiveViewTestTest do
  use Surface.ConnCase, async: true

  describe "catalogue_test" do
    test "passing a module (subject)" do
      tests = get_test_functions(Surface.LiveViewTestTest.PassingCatalogueSubjectTests)

      assert tests == [
               # Using Example
               {:"test Surface.LiveViewTestTest.FakeExample.render", 1},
               # Using Examples
               {:"test Surface.LiveViewTestTest.FakeExamples.example_with_assert_text", 1},
               {:"test Surface.LiveViewTestTest.FakeExamples.example_with_assert_texts", 1},
               {:"test Surface.LiveViewTestTest.FakeExamples.example_with_opts", 1},
               {:"test Surface.LiveViewTestTest.FakeExamples.example_without_opts", 1},
               # Using Playground
               {:"test Surface.LiveViewTestTest.FakePlayground", 1}
             ]
    end

    test "passing :all" do
      tests = get_test_functions(Surface.LiveViewTestTest.PassingCatalogueAllTests)

      assert {:"test Surface.LiveViewTestTest.FakeExample.render", 1} in tests
      assert {:"test Surface.LiveViewTestTest.FakeExampleForOtherFakeComponent.render", 1} in tests
    end

    test "passing :all with the :except option" do
      tests = get_test_functions(Surface.LiveViewTestTest.PassingCatalogueAllAndExceptTests)

      assert {:"test Surface.LiveViewTestTest.FakeExample.render", 1} in tests
      refute {:"test Surface.LiveViewTestTest.FakeExampleForOtherFakeComponent.render", 1} in tests
    end
  end

  defp get_test_functions(module) do
    module.module_info(:functions)
    |> Enum.filter(fn {f, _} -> String.starts_with?("#{f}", "test ") end)
  end
end
