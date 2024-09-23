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
               # Using Examples
               {:"test Surface.LiveViewTestTest.FakeExamples.example_with_assert_text", 1},
               {:"test Surface.LiveViewTestTest.FakeExamples.example_with_assert_texts", 1},
               {:"test Surface.LiveViewTestTest.FakeExamples.example_with_opts", 1},
               {:"test Surface.LiveViewTestTest.FakeExamples.example_without_opts", 1},
               # Using LiveExample
               {:"test Surface.LiveViewTestTest.FakeLiveExample.render", 1},
               # Using Playground
               {:"test Surface.LiveViewTestTest.FakePlayground", 1}
             ]
    end

    test "passing :all" do
      tests = get_test_functions(Surface.LiveViewTestTest.PassingCatalogueAllTests)

      assert {:"test Surface.LiveViewTestTest.FakeLiveExample.render", 1} in tests
      assert {:"test Surface.LiveViewTestTest.FakeLiveExampleForOtherFakeComponent.render", 1} in tests
    end

    test "passing :all with the :except option" do
      tests = get_test_functions(Surface.LiveViewTestTest.PassingCatalogueAllAndExceptTests)

      assert {:"test Surface.LiveViewTestTest.FakeLiveExample.render", 1} in tests
      refute {:"test Surface.LiveViewTestTest.FakeLiveExampleForOtherFakeComponent.render", 1} in tests
    end

    test "warns when passing an undefined module (subject)" do
      import ExUnit.CaptureIO

      code = """
      catalogue_test(Surface.LiveViewTestTest.UndefinedModule)
      """

      assert capture_io(:stderr, fn ->
               Code.eval_string(code, [], %{__ENV__ | line: 1})
             end) =~ "module Surface.LiveViewTestTest.UndefinedModule could not be loaded"
    end

    test "warns when passing a module that isn't a component (subject)" do
      import ExUnit.CaptureIO

      code = """
      catalogue_test(String)
      """

      assert capture_io(:stderr, fn ->
               Code.eval_string(code, [], %{__ENV__ | line: 1})
             end) =~ "module String is not a component"
    end

    test "warns when passing an undefined module (subject) :all with the :except option" do
      import ExUnit.CaptureIO

      code = """
      defmodule Test do
        use ExUnit.Case
        @before_compile Surface.LiveViewTestTest.DisableTests
        catalogue_test(:all, except: [Surface.LiveViewTestTest.UndefinedModule])
      end
      """

      assert capture_io(:stderr, fn -> Code.eval_string(code, [], __ENV__) end) =~
               "module Surface.LiveViewTestTest.UndefinedModule could not be loaded"
    end

    test "warns when passing a module that isn't a component :all with the :except option" do
      import ExUnit.CaptureIO
      unique_test_module = "Test_#{:erlang.unique_integer([:positive])}"

      code = """
      defmodule #{unique_test_module} do
        use ExUnit.Case
        @before_compile Surface.LiveViewTestTest.DisableTests
        catalogue_test(:all, except: [String])
      end
      """

      assert capture_io(:stderr, fn -> Code.eval_string(code, [], __ENV__) end) =~
               "module String is not a component"
    end
  end

  defp get_test_functions(module) do
    module.module_info(:functions)
    |> Enum.filter(fn {f, _} -> String.starts_with?("#{f}", "test ") end)
  end
end
