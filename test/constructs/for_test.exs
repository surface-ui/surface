defmodule Surface.Constructs.ForTest do
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

  test "iterates over the provided list" do
    code =
      quote do
        ~H"""
        <For each={{ fruit <- ["apples", "bananas", "oranges"] }}>
        <span>{{ fruit }}</span>
        </For>
        """
      end

    assert render_live(code) =~ """
           <span>apples</span>\
           <span>bananas</span>\
           <span>oranges</span>
           """
  end

  test "parser error message contains the correct line" do
    code =
      quote do
        ~H"""
        <For each={{ fruit <- ["apples", "bananas", "oranges"] }}>
          <span>The inner content
        </For>
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
        <For each={{ fruit <- ["apples", "bananas", "oranges"] }}>
          <ListProp prop="some string">The inner content</ListProp>
        </For>
        """
      end

    message = ~S(code:2: invalid value for property "prop". Expected a :list, got: "some string".)

    assert_raise(CompileError, message, fn ->
      render_live(code)
    end)
  end
end
