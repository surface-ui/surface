defmodule Surface.Constructs.IfTest do
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

  test "renders inner if condition is truthy" do
    alias Surface.Constructs.If

    html =
      render_surface do
        ~H"""
        <If condition={true}>
        <span>The inner content</span>
        <span>with multiple tags</span>
        </If>
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
        ~H"""
        <If condition={true}>
          <span>The inner content
        </If>
        """
      end

    message = ~S(code:2:12: expected closing tag for <span> defined on line 2, got </If>)

    assert_raise(Surface.Compiler.ParseError, message, fn ->
      compile_surface(code)
    end)
  end

  test "compile error message contains the correct line" do
    code =
      quote do
        ~H"""
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
          ~H"""
          <#if condition={true}>
          <span>The inner content</span>
          <span>with multiple tags</span>
          </#if>
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
          ~H"""
          <#if condition={true}>
            <span>The inner content
          </#if>
          """
        end

      message = ~S(code:2: expected closing tag for <span>)

      assert_raise(Surface.Compiler.ParseError, message, fn ->
        compile_surface(code)
      end)
    end

    test "compile error message contains the correct line" do
      code =
        quote do
          ~H"""
          <#if condition={false}>
            <ListProp prop="some string" />
          </#if>
          """
        end

      message =
        ~S(code:2: invalid value for property "prop". Expected a :list, got: "some string".)

      assert_raise(CompileError, message, fn ->
        compile_surface(code)
      end)
    end
  end

  describe "#else language structure" do
    test "renders inner if condition if condition is truthy" do
      html =
        render_surface do
          ~H"""
          <#if condition={true}>
          <span>The inner content</span>
          <span>with multiple tags</span>
          <#else>
          <span>The else content</span>
          <span>with multiple tags</span>
          </#if>
          """
        end

      assert html =~ """
             <span>The inner content</span>
             <span>with multiple tags</span>
             """
    end

    test "renders inner else condition is falsly" do
      html =
        render_surface do
          ~H"""
          <#if condition={false}>
          <span>The inner content</span>
          <span>with multiple tags</span>
          <#else>
          <span>The else content</span>
          <span>with multiple tags</span>
          </#if>
          """
        end

      assert html =~ """
             <span>The else content</span>
             <span>with multiple tags</span>
             """
    end
  end

  describe "#elseif language structure" do
    test "renders inner elseif condition is truthy without else" do
      html =
        render_surface do
          ~H"""
          <#if condition={false}>
            IF
          <#elseif condition={true}>
            ELSEIF TRUE
          </#if>
          """
        end

      assert html =~ """
             ELSEIF TRUE
             """
    end

    test "renders multiple inner elseif condition is truthy returns the first true block" do
      html =
        render_surface do
          ~H"""
          <#if condition={false}>
            IF
          <#elseif condition={true}>
            ELSEIF TRUE 1
          <#elseif condition={true}>
            ELSEIF TRUE 2
          </#if>
          """
        end

      assert html =~ """
             ELSEIF TRUE 1
             """
    end

    test "renders inner elseif condition is falsy without else" do
      html =
        render_surface do
          ~H"""
          <#if condition={false}>
            IF
          <#elseif condition={false}>
            ELSEIF FALSE
          <#elseif condition={false}>
            ELSEIF TRUE
          </#if>
          """
        end

      assert html =~ ""
    end

    test "renders inner elseif condition is falsly" do
      html =
        render_surface do
          ~H"""
          <#if condition={false}>
          <span>The inner content</span>
          <span>with multiple tags</span>
          <#elseif condition={false}>
          <span>The elseif content</span>
          <span>with multiple tags</span>
          <#else>
          <span>The else content</span>
          <span>with multiple tags</span>
          </#if>
          """
        end

      assert html =~ """
             <span>The else content</span>
             <span>with multiple tags</span>
             """
    end

    test "renders inner elseif condition is truthy" do
      html =
        render_surface do
          ~H"""
          <#if condition={false}>
          <span>The inner content</span>
          <span>with multiple tags</span>
          <#elseif condition={true}>
          <span>The elseif content</span>
          <span>with multiple tags</span>
          <#else>
          <span>The else content</span>
          <span>with multiple tags</span>
          </#if>
          """
        end

      assert html =~ """
             <span>The elseif content</span>
             <span>with multiple tags</span>
             """
    end

    test "renders inner if condition is truthy" do
      html =
        render_surface do
          ~H"""
          <#if condition={true}>
          <span>The inner content</span>
          <span>with multiple tags</span>
          <#elseif condition={true}>
          <span>The elseif content</span>
          <span>with multiple tags</span>
          <#else>
          <span>The else content</span>
          <span>with multiple tags</span>
          </#if>
          """
        end

      assert html =~ """
             <span>The inner content</span>
             <span>with multiple tags</span>
             """
    end
  end

  describe "nested if/elseif/else" do
    test "renders inner elseif condition is falsy without else" do
      html =
        render_surface do
          ~H"""
          <#if condition={false}>
            IF
          <#elseif condition={false}>
            ELSEIF FALSE
          <#elseif condition={true}>
            BEFORE
            <#if condition={false}>
              NESTED IF
            <#elseif condition={true}>
              NESTED ELSEIF TRUE
            <#else>
              NESTED FALSE
            </#if>
            AFTER
          <#else>
            ELSE
          </#if>
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
          ~H"""
          <#if condition={false}>
            IF
          <#elseif condition={false}>
            ELSEIF FALSE
          <#elseif condition={true}>
            BEFORE
            <#if condition={false}>
              NESTED IF
            <#elseif condition={true}>
              NESTED ELSEIF TRUE
            <#else>
              <ListProp prop="some string" />
            </#if>
            AFTER
          <#else>
            ELSE
          </#if>
          """
        end

      message =
        ~S(code:12: invalid value for property "prop". Expected a :list, got: "some string".)

      assert_raise(CompileError, message, fn ->
        compile_surface(code)
      end)
    end

    test "parser error message contains the correct line with nested struct" do
      code =
        quote do
          ~H"""
          <#if condition={false}>
            IF
          <#elseif condition={false}>
            ELSEIF FALSE
          <#elseif condition={true}>
            BEFORE
            <#if condition={false}>
              NESTED IF
            <#elseif condition={true}>
              NESTED ELSEIF TRUE
            <#else>
              ELSE
              <span>Some text
            </#if>
            AFTER
          <#else>
            ELSE
          </#if>
          """
        end

      message = ~S(code:13: expected closing tag for <span>)

      assert_raise(Surface.Compiler.ParseError, message, fn ->
        compile_surface(code)
      end)
    end
  end
end
