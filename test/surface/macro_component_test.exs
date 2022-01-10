defmodule Surface.MacroComponentTest do
  use Surface.ConnCase

  import ExUnit.CaptureIO

  defmodule RenderContent do
    use Surface.MacroComponent

    alias Surface.MacroComponent

    slot default

    def expand(_attributes, content, _meta) do
      quote_surface do
        ~F[{^content}]
      end
    end
  end

  defmodule Upcase do
    use Surface.MacroComponent

    alias Surface.MacroComponent

    prop class, :css_class
    prop align, :string, static: true

    slot default

    def expand(attributes, content, meta) do
      # Static prop
      static_props = MacroComponent.eval_static_props!(__MODULE__, attributes, meta.caller)
      align = static_props[:align] || false

      # String
      upcase_content = content |> String.trim() |> String.upcase()
      title = "Some title"

      # Boolean
      disabled = true
      hidden = false

      # Integer
      tabindex = 1

      # AST
      id = %Surface.AST.Literal{value: "123"}
      class = Surface.AST.find_attribute_value(attributes, :class) || ""

      # AST generated by `quote_surface`
      span =
        quote_surface do
          ~F"""
          <span
            align={^align}
            title={^title}
            disabled={^disabled}
            hidden={^hidden}
            tabindex={^tabindex}
            id={^id}
            class={^class}
          >
            {^upcase_content}
          </span>
          """
        end

      quote_surface do
        ~F"""
        <div>
        {^span}
        </div>
        """
      end
    end
  end

  test "empty content is translated to empty string" do
    assert render_surface(do: ~F[<#RenderContent />]) == ""
    assert render_surface(do: ~F[<#RenderContent></#RenderContent>]) == ""
  end

  test "non empty content is translated to non empty string" do
    assert render_surface(do: ~F[<#RenderContent>ABC</#RenderContent>]) == "ABC"
  end

  test "parses its own content" do
    html =
      render_surface do
        ~F"""
        <#Upcase>
          This text is not parsed by Surface. The following should not be translated:
            - {no interpolation}
            - `</#Surface.Components.Raw>`
        </#Upcase>
        """
      end

    assert html =~ ~r"""
           <div>
           <span (.+)>
             THIS TEXT IS NOT PARSED BY SURFACE. THE FOLLOWING SHOULD NOT BE TRANSLATED:
               - {NO INTERPOLATION}
               - `</#SURFACE.COMPONENTS.RAW>`
           </span>
           </div>
           """
  end

  test "generates attributes from strings, booleans, integers and AST" do
    assigns = %{class: "some_class"}

    html =
      render_surface do
        ~F"""
        <#Upcase>
          content
        </#Upcase>
        """
      end

    assert html =~ """
           <div>
           <span title="Some title" disabled tabindex="1" id="123" class="">
             CONTENT
           </span>
           </div>
           """
  end

  test "accept attributes values passed as static values" do
    html =
      render_surface do
        ~F"""
        <#Upcase align="center">
          content
        </#Upcase>
        """
      end

    assert html =~ ~r"""
           <div>
           <span align="center"(.+)>
             CONTENT
           </span>
           </div>
           """
  end

  test "accept attributes values passed as dynamic expressions" do
    assigns = %{class: "some_class"}

    html =
      render_surface do
        ~F"""
        <#Upcase class={@class}>
          content
        </#Upcase>
        """
      end

    assert html =~ ~r"""
           <div>
           <span (.+) class="some_class">
             CONTENT
           </span>
           </div>
           """
  end

  test "errors in dynamic expressions are reported at the right line" do
    code =
      quote do
        ~F"""
        <#Upcase
          class={,}
        >
          content
        </#Upcase>
        """
      end

    assert_raise(SyntaxError, ~r/code:2: syntax error before: ','/, fn ->
      compile_surface(code)
    end)
  end

  test "static properties do not accept runtime expressions" do
    code =
      quote do
        ~F"""
        <#Upcase
          align={@align}>
          content
        </#Upcase>
        """
      end

    message = """
    code:2: invalid value for property "align"

    Expected a string while evaluating {@align}, got: nil

    Hint: static properties of macro components can only accept static values like module attributes,
    literals or compile-time expressions. Runtime variables and expressions, including component
    assigns, cannot be evaluated as they are not available during compilation.
    """

    assert_raise(CompileError, message, fn ->
      capture_io(:standard_error, fn ->
        compile_surface(code, %{class: "markdown"})
      end)
    end)
  end
end
