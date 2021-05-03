defmodule Surface.Constructs.ForTest do
  use Surface.ConnCase, async: true

  defmodule ListProp do
    use Surface.Component

    prop prop, :list

    def render(assigns) do
      ~H"""
      List?: {is_list(@prop)}
      <span :for={v <- @prop}>value: {inspect(v)}</span>
      """
    end
  end

  test "iterates over the provided list" do
    alias Surface.Constructs.For

    html =
      render_surface do
        ~H"""
        <For each={fruit <- ["apples", "bananas", "oranges"]}>
        <span>{fruit}</span>
        </For>
        """
      end

    assert html =~ """
           <span>apples</span>
           <span>bananas</span>
           <span>oranges</span>
           """
  end

  test "parser error message contains the correct line" do
    code =
      quote do
        ~H"""
        <For each={fruit <- ["apples", "bananas", "oranges"]}>
          <span>The inner content
        </For>
        """
      end

    message = ~S(code:2:4: expected closing tag for <span> defined on line 2, got </For>)

    assert_raise(Surface.Compiler.ParseError, message, fn ->
      compile_surface(code)
    end)
  end

  test "compile error message contains the correct line" do
    code =
      quote do
        ~H"""
        <For each={fruit <- ["apples", "bananas", "oranges"]}>
          <ListProp prop="some string" />
        </For>
        """
      end

    message = ~S(code:2: invalid value for property "prop". Expected a :list, got: "some string".)

    assert_raise(CompileError, message, fn ->
      compile_surface(code)
    end)
  end
end
