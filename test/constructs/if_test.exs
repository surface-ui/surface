defmodule Surface.Constructs.IfTest do
  use Surface.ConnCase, async: true
  import ExUnit.CaptureIO

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

  test "warn when using deprecated <If>" do
    code =
      quote do
        ~H"""
        <If condition={{ true }}>
          Warning
        </If>
        """
      end

    output =
      capture_io(:standard_error, fn ->
        compile_surface(code)
      end)

    assert output =~ ~r"""
           using <If> to wrap elements in an if experssion has been depreacated and will be removed in \
           future versions.

           Hint: replace `<If>` with `<#if>`

             code:1:\
           """
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

      message = ~S(code:2:14: expected closing tag for <span> defined on line 2, got </#if>)

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
    test "renders inner `if` condition, if condition is truthy" do
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

    test "renders inner `else` condition if condition is fasly" do
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
    test "renders inner `elseif` condition if condition is truthy" do
      html =
        render_surface do
          ~H"""
          <#if condition={false}>
            IF
          <#elseif condition={true}>
            ELSEIF TRUE
          <#else>
            ELSE
          </#if>
          """
        end

      assert html =~ """
             ELSEIF TRUE
             """
    end

    test "renders inner `elseif` condition if condition is truthy even without an else clause" do
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

    test "renders nothing if all conditions are falsly" do
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

    test "renders inner `else` condition if all `elseif` conditions are falsly" do
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

    test "renders only first truthy condition" do
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
    test "renders inner `elseif` condition if condition is truthy" do
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

      message = ~S(code:13:16: expected closing tag for <span> defined on line 13, got </#if>)

      assert_raise(Surface.Compiler.ParseError, message, fn ->
        compile_surface(code)
      end)
    end
  end
end
