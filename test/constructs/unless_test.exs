defmodule Surface.Constructs.UnlessTest do
  use ExUnit.Case, async: true

  import ComponentTestHelper

  defmodule ListProp do
    use Surface.Component

    prop prop, :list

    def render(assigns) do
      ~H"""
      List?: {{ is_list(@prop) }}
      <span :for={{ v <- @prop }}>value: {{inspect(v)}}</span>
      """
    end
  end

  test "renders inner unless condition is false" do
    code =
      quote do
        ~H"""
        <Unless condition={{ false }}>
        <span>The inner content</span>
        <span>with multiple tags</span>
        </Unless>
        """
      end

    assert render_live(code) =~ """
           <span>The inner content</span>\
           <span>with multiple tags</span>
           """
  end

  test "parser error message contains the correct line" do
    code =
      quote do
        ~H"""
        <Unless condition={{ false }}>
          <span>The inner content
        </Unless>
        """
      end

    message = ~S(code:2: expected closing tag for "span")

    assert_raise(Surface.Compiler.ParseError, message, fn ->
      render_live(code)
    end)
  end

  test "compile error message contains the correct line" do
    code =
      quote do
        ~H"""
        <Unless condition={{ false }}>
          <ListProp prop="some string">The inner content</ListProp>
        </Unless>
        """
      end

    message = ~S(code:2: invalid value for property "prop". Expected a :list, got: "some string".)

    assert_raise(CompileError, message, fn ->
      render_live(code)
    end)
  end
end
