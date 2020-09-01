defmodule ContextTest do
  use ExUnit.Case, async: true

  import Surface
  import ComponentTestHelper

  defmodule Outer do
    use Surface.Component

    context set field, :any, scope: :only_children

    def init_context(_assigns) do
      {:ok, field: "field from Outer"}
    end

    def render(assigns) do
      ~H"""
      <div>{{ @inner_content.([]) }}</div>
      """
    end
  end

  defmodule RenderContext do
    use Surface.Component

    def render(assigns) do
      ~H"""
      Context: {{ inspect(@__context__) }}
      """
    end
  end

  defmodule Inner do
    use Surface.Component

    context get field, from: ContextTest.Outer
    context get field, from: ContextTest.InnerWrapper, as: :other_field

    def render(assigns) do
      ~H"""
      <span id="field">{{ @field }}</span>
      <span id="other_field">{{ @other_field }}</span>
      """
    end
  end

  defmodule InnerWrapper do
    use Surface.Component

    context set field, :any

    def init_context(_assigns) do
      {:ok, field: "field from InnerWrapper"}
    end

    def render(assigns) do
      ~H"""
      <Inner />
      """
    end
  end

  defmodule InnerWithOptionAs do
    use Surface.Component

    context get field, from: Outer, as: :my_field

    def render(assigns) do
      ~H"""
      <span>{{ @my_field }}</span>
      """
    end
  end

  test "pass context to child component" do
    code = """
    <Outer>
      <Inner/>
    </Outer>
    """

    assert render_live(code) =~ """
           <span id="field">field from Outer</span>\
           """
  end

  test "pass context to child component using :as option" do
    code = """
    <Outer>
      <InnerWithOptionAs/>
    </Outer>
    """

    assert render_live(code) =~ """
           <div><span>field from Outer</span></div>
           """
  end

  test "pass context down the tree of components" do
    code = """
    <Outer>
      <InnerWrapper />
    </Outer>
    """

    assert render_live(code) =~ """
           <span id="field">field from Outer</span>\
           """
  end

  test "context assingns are scoped by their parent components" do
    code = """
    <Outer>
      <InnerWrapper/>
    </Outer>
    """

    assert render_live(code) =~ """
           <span id="field">field from Outer</span>\
           <span id="other_field">field from InnerWrapper</span>\
           """
  end

  test "reset context after the component" do
    code = """
    <Outer>
      <Inner/>
    </Outer>
    <RenderContext/>
    """

    assert render_live(code) =~ """
           Context: []
           """
  end
end
