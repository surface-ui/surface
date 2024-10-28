defmodule Surface.Constructs.IfTest do
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

  describe "#if language structure" do
    test "renders inner if condition is truthy" do
      html =
        render_surface do
          ~F"""
          {#if true}
          <span>The inner content</span>
          <span>with multiple tags</span>
          {/if}
          """
        end

      assert html =~ """
             <span>The inner content</span>
             <span>with multiple tags</span>
             """
    end

    test "renders inner if condition with component" do
      html =
        render_surface do
          ~F"""
          {#if true}
            <SomeComponent content="The inner content" />
          {/if}
          """
        end

      assert html =~ """
             <span>The inner content</span>
             """
    end

    test "parser error message contains the correct line" do
      code =
        quote do
          ~F"""
          {#if true}
            <span>The inner content
          {/if}
          """
        end

      message = ~S(code:3:13: expected closing tag for <span> defined on line 2, got {/if})

      assert_raise(Surface.Compiler.ParseError, message, fn ->
        compile_surface(code)
      end)
    end

    test "compile error message contains the correct line" do
      code =
        quote do
          ~F"""
          {#if false}
            <ListProp prop="some string" />
          {/if}
          """
        end

      message =
        ~r/code:2:\n#{maybe_ansi("error:")} invalid value for property "prop". Expected a :list, got: "some string"./

      assert_raise(Surface.CompileError, message, fn ->
        compile_surface(code)
      end)
    end
  end

  describe "#else language structure" do
    test "renders inner `if` condition, if condition is truthy" do
      html =
        render_surface do
          ~F"""
          {#if true}
            <span>The inner content</span>
            <span>with multiple tags</span>
          {#else}
            <span>The else content</span>
            <span>with multiple tags</span>
          {/if}
          """
        end

      assert html =~ """
               <span>The inner content</span>
               <span>with multiple tags</span>
             """
    end

    test "renders inner `else` condition if condition is falsy" do
      html =
        render_surface do
          ~F"""
          {#if false}
            <span>The inner content</span>
            <span>with multiple tags</span>
          {#else}
            <span>The else content</span>
            <span>with multiple tags</span>
          {/if}
          """
        end

      assert html =~ """
               <span>The else content</span>
               <span>with multiple tags</span>
             """
    end

    test "renders inner `else` condition with component" do
      html =
        render_surface do
          ~F"""
          {#if false}
            <span>The inner content</span>
            <span>with multiple tags</span>
          {#else}
            <SomeComponent content="The else content" />
          {/if}
          """
        end

      assert html =~ """
               <span>The else content</span>
             """
    end
  end

  describe "#elseif language structure" do
    test "renders inner `elseif` condition if condition is truthy" do
      html =
        render_surface do
          ~F"""
          {#if false}
            IF
          {#elseif true}
            ELSEIF TRUE
          {#else}
            ELSE
          {/if}
          """
        end

      assert html =~ """
             ELSEIF TRUE
             """
    end

    test "renders inner `elseif` condition if condition is truthy even without an else clause" do
      html =
        render_surface do
          ~F"""
          {#if false}
            IF
          {#elseif true}
            ELSEIF TRUE
          {/if}
          """
        end

      assert html =~ """
             ELSEIF TRUE
             """
    end

    test "renders nothing if all conditions are fasly" do
      html =
        render_surface do
          ~F"""
          {#if false}
            IF
          {#elseif false}
            ELSEIF FALSE
          {#elseif false}
            ELSEIF TRUE
          {/if}
          """
        end

      assert html =~ ""
    end

    test "renders inner `else` condition if all `elseif` conditions are fasly" do
      html =
        render_surface do
          ~F"""
          {#if false}
            <span>The inner content</span>
            <span>with multiple tags</span>
          {#elseif false}
            <span>The elseif content</span>
            <span>with multiple tags</span>
          {#else}
            <span>The else content</span>
            <span>with multiple tags</span>
          {/if}
          """
        end

      assert html =~ """
               <span>The else content</span>
               <span>with multiple tags</span>
             """
    end

    test "renders only first truthy condition" do
      html =
        render_surface do
          ~F"""
          {#if true}
            <span>The inner content</span>
            <span>with multiple tags</span>
          {#elseif true}
            <span>The elseif content</span>
            <span>with multiple tags</span>
          {#else}
            <span>The else content</span>
            <span>with multiple tags</span>
          {/if}
          """
        end

      assert html =~ """
               <span>The inner content</span>
               <span>with multiple tags</span>
             """
    end
  end

  describe "nested if/elseif/else" do
    test "renders inner `elseif` condition if condition is truthy" do
      html =
        render_surface do
          ~F"""
          {#if false}
            IF
          {#elseif false}
            ELSEIF FALSE
          {#elseif true}
            BEFORE
            {#if false}
              NESTED IF
            {#elseif true}
              NESTED ELSEIF TRUE
            {#else}
              NESTED FALSE
            {/if}
            AFTER
          {#else}
            ELSE
          {/if}
          """
        end

      assert html =~ """
               BEFORE
                 NESTED ELSEIF TRUE
               AFTER
             """
    end

    test "compile error message contains the correct line with nested struct" do
      code =
        quote do
          ~F"""
          {#if false}
            IF
          {#elseif false}
            ELSEIF FALSE
          {#elseif true}
            BEFORE
            {#if false}
              NESTED IF
            {#elseif true}
              NESTED ELSEIF TRUE
            {#else}
              <ListProp prop="some string" />
            {/if}
            AFTER
          {#else}
            ELSE
          {/if}
          """
        end

      message =
        ~r/code:12:\n#{maybe_ansi("error:")} invalid value for property "prop". Expected a :list, got: "some string"./

      assert_raise(Surface.CompileError, message, fn ->
        compile_surface(code)
      end)
    end

    test "parser error message contains the correct line with nested struct" do
      code =
        quote do
          ~F"""
          {#if false}
            IF
          {#elseif false}
            ELSEIF FALSE
          {#elseif true}
            BEFORE
            {#if false}
              NESTED IF
            {#elseif true}
              NESTED ELSEIF TRUE
            {#else}
              ELSE
              <span>Some text
            {/if}
            AFTER
          {#else}
            ELSE
          {/if}
          """
        end

      message = ~S(code:14:15: expected closing tag for <span> defined on line 13, got {/if})

      assert_raise(Surface.Compiler.ParseError, message, fn ->
        compile_surface(code)
      end)
    end
  end

  describe "#unless language structure" do
    test "renders inner unless condition is falsy" do
      html =
        render_surface do
          ~F"""
          {#unless false}
            <span>The inner content</span>
            <span>with multiple tags</span>
          {/unless}
          """
        end

      assert html =~ """
               <span>The inner content</span>
               <span>with multiple tags</span>
             """
    end

    test "parser error message contains the correct line" do
      code =
        quote do
          ~F"""
          {#unless false}
            <span>The inner content
          {/unless}
          """
        end

      message = ~S(code:3:13: expected closing tag for <span> defined on line 2, got {/unless})

      assert_raise(Surface.Compiler.ParseError, message, fn ->
        compile_surface(code)
      end)
    end

    test "compile error message contains the correct line" do
      code =
        quote do
          ~F"""
          {#unless false}
            <ListProp prop="some string" />
          {/unless}
          """
        end

      message =
        ~r/code:2:\n#{maybe_ansi("error:")} invalid value for property "prop". Expected a :list, got: "some string"./

      assert_raise(Surface.CompileError, message, fn ->
        compile_surface(code)
      end)
    end
  end
end
