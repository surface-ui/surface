defmodule SurfaceTest do
  use Surface.ConnCase

  doctest Surface, import: true

  import Surface

  describe "quote_surface" do
    test "generate AST" do
      [tag] =
        quote_surface line: 1 do
          ~F"<div>content</div>"
        end

      assert %Surface.AST.Tag{
               element: "div",
               children: [%Surface.AST.Literal{value: "content"}],
               meta: %{line: 1}
             } = tag
    end

    test "using heredocs" do
      [tag | _] =
        quote_surface line: 1 do
          ~F"""
          <div>content</div>
          """
        end

      assert %Surface.AST.Tag{
               element: "div",
               children: [%Surface.AST.Literal{value: "content"}],
               meta: %{line: 1}
             } = tag
    end
  end

  describe "components" do
    test "retrieve all components" do
      list = components()

      # We cannot assert if it retrieves deps' components from here since this project cannot
      # depend on a another project that depends on surface itself. So we just make sure it
      # retrieves, at least, the list of components of this project.
      assert Surface.Components.Raw in list
      assert Enum not in list
    end

    test "retrieve only components in the current project" do
      list = components(only_current_project: true)

      assert Surface.Components.Raw in list
      assert Enum not in list

      # We cannot test `only_current_project: false` from here since this project cannot
      # depend on a another project that depends on surface itself. So we just make sure it
      # retrieves, at least, the list of components of this project.
      list = components(only_current_project: false)

      assert Surface.Components.Raw in list
      assert Enum not in list
    end
  end

  test "raise error when trying to unquote an undefined variable" do
    message = ~r"""
    code.ex:2:
    #{maybe_ansi("error:")} undefined variable "content"\.

    Available variable: "message"
    """

    assert_raise(Surface.CompileError, message, fn ->
      quote_surface line: 1, file: "code.ex" do
        ~F"""
        <div>
          {^content}
        </div>
        """
      end
    end)
  end

  test "raise error when trying to unquote expressions that are not variables" do
    message = ~r"""
    code.ex:2:
    #{maybe_ansi("error:")} cannot unquote `to_string\(:abc\)`\.

    The expression to be unquoted must be written as `\^var`, where `var` is an existing variable\.
    """

    assert_raise(Surface.CompileError, message, fn ->
      quote_surface line: 1, file: "code.ex" do
        ~F"""
        <div>
          {^to_string(:abc)}
        </div>
        """
      end
    end)
  end

  test "raise error when not using the ~F sigil" do
    code = """
    quote_surface do
      "\""
      <div>
        {^to_string(:abc)}
      </div>
      "\""
    end
    """

    message = ~r"code.exs:1:\n#{maybe_ansi("error:")} the code to be quoted must be wrapped in a `~F` sigil\."

    assert_raise(Surface.CompileError, message, fn ->
      {{:module, _, _, _}, _} = Code.eval_string(code, [], %{__ENV__ | file: "code.exs", line: 1})
    end)
  end

  test "raise error when using {^...} outside `quote_surface`" do
    message = ~r"code:2:\n#{maybe_ansi("error:")} cannot use tagged expression \{\^var\} outside `quote_surface`"

    code =
      quote do
        ~F"""
        <div>
          {^content}
        </div>
        """
      end

    assert_raise(Surface.CompileError, message, fn ->
      compile_surface(code)
    end)
  end

  describe "embed_sface" do
    embed_sface("surface_test_embed_sface.sface")

    test "generate function that renders the given template" do
      assert %Phoenix.LiveView.Rendered{
               static: ["<div>embed_sface</div>"]
             } = __MODULE__.surface_test_embed_sface(%{})
    end
  end
end
