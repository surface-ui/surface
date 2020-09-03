defmodule ContextTest do
  use ExUnit.Case, async: true

  import Surface
  import ComponentTestHelper

  defmodule Outer do
    use Surface.Component

    def render(assigns) do
      ~H"""
      <Context set={{ :field, "field from Outer", scope: __MODULE__ }}>
        <div><slot/></div>
      </Context>
      """
    end
  end

  defmodule OuterUsingInnerContent do
    use Surface.Component

    def render(assigns) do
      ~H"""
      <Context set={{ :field, "field from OuterUsingInnerContent", scope: __MODULE__ }}>
        <div>{{ @inner_content.([]) }}</div>
      </Context>
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

    def render(assigns) do
      ~H"""
      <Context
        get={{ :field, scope: ContextTest.Outer }}
        get={{ :field, scope: ContextTest.InnerWrapper, as: :other_field }}>
        <span id="field">{{ @field }}</span>
        <span id="other_field">{{ @other_field }}</span>
      </Context>
      """
    end
  end

  defmodule InnerWrapper do
    use Surface.Component

    def render(assigns) do
      ~H"""
      <Context set={{ :field, "field from InnerWrapper", scope: __MODULE__ }}>
        <Inner />
      </Context>
      """
    end
  end

  defmodule InnerWithOptionAs do
    use Surface.Component

    def render(assigns) do
      ~H"""
      <Context get={{ :field, scope: ContextTest.Outer, as: :my_field }}>
        <span>{{ @my_field }}</span>
      </Context>
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

  # TODO: Fix it!
  # test "pass context to child component with @inner_content" do
  #   code = """
  #   <OuterUsingInnerContent>
  #     <Inner/>
  #   </OuterUsingInnerContent>
  #   """

  #   assert render_live(code) =~ """
  #          <span id="field">field from OuterUsingInnerContent</span>\
  #          """
  # end

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
           Context: %{}
           """
  end
end
