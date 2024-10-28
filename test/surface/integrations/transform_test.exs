defmodule Surface.TransformTest do
  use Surface.Case

  defmodule Span do
    use Surface.Component

    slot default

    def render(assigns) do
      ~F"""
      <span><#slot /></span>
      """
    end
  end

  defmodule DivToSpan do
    use Surface.Component

    slot default

    @impl true
    def render(assigns) do
      ~F"""
      <div><#slot /></div>
      """
    end

    @impl Surface.BaseComponent
    def transform(node) do
      send(self(), {DivToSpan, "transforming node"})
      %{node | module: Span}
    end
  end

  defmodule LiveDivToSpan do
    use Surface.LiveComponent

    slot default

    @impl true
    def render(assigns) do
      ~F"""
      <div><#slot /></div>
      """
    end

    @impl Surface.BaseComponent
    def transform(node) do
      send(self(), {LiveDivToSpan, "transforming node"})
      %{node | module: Span, type: Surface.Component}
    end
  end

  defmodule LiveDivViewToSpan do
    use Surface.LiveView

    @impl true
    def render(assigns) do
      ~F"""
      <div></div>
      """
    end

    @impl Surface.BaseComponent
    def transform(node) do
      send(self(), {LiveDivViewToSpan, "transforming node"})
      %{node | module: Span, type: Surface.Component}
    end
  end

  defmodule MacroDivToSpan do
    use Surface.MacroComponent

    @impl true
    def expand(_, _, _) do
      Surface.Compiler.compile(
        """
        <span>This is a test component. Don't do this at home.</span>
        """,
        1,
        __ENV__
      )
    end

    @impl Surface.BaseComponent
    def transform(node) do
      send(self(), {MacroDivToSpan, "transforming node"})
      node
    end
  end

  defmodule ListProp do
    use Surface.Component

    prop prop, :list

    @impl true
    def render(assigns) do
      ~F"""
      <span></span>
      """
    end

    @impl Surface.BaseComponent
    def transform(node) do
      send(self(), {ListProp, "transforming node"})
      node
    end
  end

  test "transform is run on compile when defined for Surface.Component" do
    code = """
    <DivToSpan>Some content</DivToSpan>
    """

    [node | _] = Surface.Compiler.compile(code, 1, __ENV__)

    assert_receive {DivToSpan, "transforming node"}

    assert %Surface.AST.Component{
             module: Span
           } = node
  end

  test "transform is run on compile when defined for Surface.LiveComponent" do
    code = """
    <LiveDivToSpan id="div">Some content</LiveDivToSpan>
    """

    [node | _] = Surface.Compiler.compile(code, 1, __ENV__)

    assert_receive {LiveDivToSpan, "transforming node"}

    assert %Surface.AST.Component{
             module: Span
           } = node
  end

  test "transform is run on compile when defined for Surface.LiveView" do
    code = """
    <LiveDivViewToSpan id="view" />
    """

    [node | _] = Surface.Compiler.compile(code, 1, __ENV__)

    assert_receive {LiveDivViewToSpan, "transforming node"}

    assert %Surface.AST.Component{
             module: Span
           } = node
  end

  test "transform is NOT run on compile when defined for Surface.MacroComponent" do
    code = """
    <#MacroDivToSpan>Some content</#MacroDivToSpan>
    """

    [node | _] = Surface.Compiler.compile(code, 1, __ENV__)

    refute_receive {MacroDivToSpan, "transforming node"}

    assert %Surface.AST.MacroComponent{} = node
  end

  test "transform is not run on parse errors" do
    code = """
    <br>
    <DivToSpan>Invalid syntax (missing end tag)
    """

    assert_raise(
      Surface.Compiler.ParseError,
      "nofile:2:2: end of file reached without closing tag for <DivToSpan>",
      fn ->
        Surface.Compiler.compile(code, 1, __ENV__)
      end
    )

    refute_receive {DivToSpan, "transforming node"}
  end

  test "transform is not run on compile errors" do
    code = """
    <ListProp prop="string" />
    """

    assert_raise(
      Surface.CompileError,
      ~r"nofile:1:\n#{maybe_ansi("error:")} invalid value for property \"prop\"\. Expected a :list, got: \"string\".",
      fn ->
        Surface.Compiler.compile(code, 1, __ENV__)
      end
    )

    refute_receive {ListProp, "transforming node"}
  end
end
