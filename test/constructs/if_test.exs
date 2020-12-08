defmodule Surface.Constructs.IfTest do
  use Surface.ConnCase, async: true

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

  test "renders inner if condition is truthy" do
    alias Surface.Constructs.If

    html =
      render_surface do
        ~H"""
        <If condition={{ true }}>
        <span>The inner content</span>
        <span>with multiple tags</span>
        </If>
        """
      end

    assert_html(
      html =~ """
      <span>The inner content</span>\
      <span>with multiple tags</span>
      """
    )
  end

  test "parser error message contains the correct line" do
    code =
      quote do
        ~H"""
        <If condition={{ true }}>
          <span>The inner content
        </If>
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
        <If condition={{ true }}>
          <ListProp prop="some string">The inner content</ListProp>
        </If>
        """
      end

    message = ~S(code:2: invalid value for property "prop". Expected a :list, got: "some string".)

    assert_raise(CompileError, message, fn ->
      render_live(code)
    end)
  end
end
