defmodule Surface.Constructs.ForTest do
  use Surface.ConnCase, async: true

  defmodule ListProp do
    use Surface.Component

    prop prop, :list

    def render(assigns) do
      ~F"""
      List?: {is_list(@prop)}
      <span :for={v <- @prop}>value: {inspect(v)}</span>
      """
    end
  end

  defmodule SomeComponent do
    use Surface.Component

    prop content, :any

    def render(assigns) do
      ~F"""
      <span>{@content}</span>
      """
    end
  end

  describe "#for language structure" do
    test "renders inner content with generator" do
      html =
        render_surface do
          ~F"""
          {#for fruit <- ["apples", "bananas", "oranges"]}
            <span>The inner content {fruit}</span>
            <span>with multiple tags</span>
          {/for}
          """
        end

      assert html =~ """
               <span>The inner content apples</span>
               <span>with multiple tags</span>
               <span>The inner content bananas</span>
               <span>with multiple tags</span>
               <span>The inner content oranges</span>
               <span>with multiple tags</span>
             """
    end

    test "renders inner content with complex generator" do
      assigns = %{list1: [1, 4], list2: [2, 3, 4], range: 1..3}

      html =
        render_surface do
          ~F"""
          {#for x <- @list1, y <- @list2, x in @range, y in @range}
            <span>x: {x}, y: {y}</span>
          {/for}
          """
        end

      assert html =~ """
               <span>x: 1, y: 2</span>
               <span>x: 1, y: 3</span>
             """
    end

    test "renders inner content with component" do
      html =
        render_surface do
          ~F"""
          {#for fruit <- ["apples", "bananas", "oranges"]}
            <SomeComponent content={fruit} />
          {/for}
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
          ~F"""
          {#for fruit <- ["apples", "bananas", "oranges"]}
            <span>The inner content
          {/for}
          """
        end

      message = ~S(code:3:13: expected closing tag for <span> defined on line 2, got {/for})

      assert_raise(Surface.Compiler.ParseError, message, fn ->
        compile_surface(code)
      end)
    end

    test "compile error message contains the correct line" do
      code =
        quote do
          ~F"""
          {#for fruit <- ["apples", "bananas", "oranges"]}
            <ListProp
              prop="some string" />
          {/for}
          """
        end

      message =
        ~r/code:3:\n#{maybe_ansi("error:")} invalid value for property "prop". Expected a :list, got: "some string"./

      assert_raise(Surface.CompileError, message, fn ->
        compile_surface(code)
      end)
    end
  end

  describe "#else language structure" do
    test "renders inner `for` content if generator is not empty" do
      html =
        render_surface do
          ~F"""
          {#for fruit <- ["apples", "bananas", "oranges"]}
            <span>The inner content {fruit}</span>
            <span>with multiple tags</span>
          {#else}
            <span>The else content</span>
            <span>with multiple tags</span>
          {/for}
          """
        end

      assert html =~ """
               <span>The inner content apples</span>
               <span>with multiple tags</span>
               <span>The inner content bananas</span>
               <span>with multiple tags</span>
               <span>The inner content oranges</span>
               <span>with multiple tags</span>
             """
    end

    test "renders inner content with component" do
      html =
        render_surface do
          ~F"""
          {#for fruit <- ["apples", "bananas", "oranges"]}
            <SomeComponent content={fruit} />
          {#else}
            <span>The else content</span>
            <span>with multiple tags</span>
          {/for}
          """
        end

      assert html =~ """
               <span>apples</span>
               <span>bananas</span>
               <span>oranges</span>
             """
    end

    test "renders inner `for` content with assigns" do
      fruits = ["apples", "bananas", "oranges"]
      assigns = %{fruits: fruits}

      html =
        render_surface do
          ~F"""
          {#for fruit <- @fruits}
            <span>The inner content {fruit}</span>
            <span>with multiple tags</span>
          {#else}
            <span>The else content</span>
            <span>with multiple tags</span>
          {/for}
          """
        end

      assert html =~ """
               <span>The inner content apples</span>
               <span>with multiple tags</span>
               <span>The inner content bananas</span>
               <span>with multiple tags</span>
               <span>The inner content oranges</span>
               <span>with multiple tags</span>
             """
    end

    test "raises compile error with complex generator" do
      assigns = %{list1: [1, 4], list2: [2, 3, 4], range: 1..3}

      code =
        quote do
          ~F"""
          {#for x <- @list1, y <- @list2, x in @range, y in @range}
            <span>x: {x}, y: {y}</span>
          {#else}
            <span>The else content</span>
            <span>with multiple tags</span>
          {/for}
          """
        end

      message =
        ~r/code:3:\n#{maybe_ansi("error:")} using `{#else}` is only supported when the expression in `{#for}` has a single generator and no filters./

      assert_raise(Surface.CompileError, message, fn ->
        compile_surface(code, assigns)
      end)
    end

    test "renders inner `else` if generator is empty" do
      html =
        render_surface do
          ~F"""
          {#for fruit <- []}
            <span>The inner content {fruit}</span>
            <span>with multiple tags</span>
          {#else}
            <span>The else content</span>
            <span>with multiple tags</span>
          {/for}
          """
        end

      assert html =~ """
               <span>The else content</span>
               <span>with multiple tags</span>
             """
    end

    test "renders inner `else` with component" do
      html =
        render_surface do
          ~F"""
          {#for fruit <- []}
            <span>The inner content {fruit}</span>
            <span>with multiple tags</span>
          {#else}
            <SomeComponent content="The else content" />
          {/for}
          """
        end

      assert html =~ """
             <span>The else content</span>
             """
    end
  end
end
