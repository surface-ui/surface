defmodule Surface.Constructs.IfTest do
  use Surface.ConnCase, async: true
  import ExUnit.CaptureIO

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

  test "warn when using deprecated <If>" do
    code =
      quote do
        ~F"""
        <If condition={true}>
          Warning
        </If>
        """
      end

    output =
      capture_io(:standard_error, fn ->
        compile_surface(code)
      end)

    assert output =~ ~r"""
           using <If> to wrap elements in an if expression has been deprecated and will be removed in \
           future versions.

           Hint: replace `<If>` with `{#if}`

             code:1:\
           """
  end

  test "parser error message contains the correct line" do
    code =
      quote do
        ~F"""
        <If condition={true}>
          <span>The inner content
        </If>
        """
      end

    message = ~S(code:2:12: expected closing node for <span> defined on line 2, got </If>)

    assert_raise(Surface.Compiler.ParseError, message, fn ->
      capture_io(:standard_error, fn ->
        compile_surface(code)
      end)
    end)
  end

  test "compile error message contains the correct line" do
    code =
      quote do
        ~F"""
        <If condition={true}>
          <ListProp prop="some string" />
        </If>
        """
      end

    message = ~S(code:2: invalid value for property "prop". Expected a :list, got: "some string".)

    assert_raise(CompileError, message, fn ->
      compile_surface(code)
    end)
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

      message = ~S(code:2:14: expected closing node for <span> defined on line 2, got {/if})

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

      message = ~S(code:2: invalid value for property "prop". Expected a :list, got: "some string".)

      assert_raise(CompileError, message, fn ->
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

      message = ~S(code:12: invalid value for property "prop". Expected a :list, got: "some string".)

      assert_raise(CompileError, message, fn ->
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

      message = ~S(code:13:16: expected closing node for <span> defined on line 13, got {/if})

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

      message = ~S(code:2:14: expected closing node for <span> defined on line 2, got {/unless})

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

      message = ~S(code:2: invalid value for property "prop". Expected a :list, got: "some string".)

      assert_raise(CompileError, message, fn ->
        compile_surface(code)
      end)
    end
  end
end
