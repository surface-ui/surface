defmodule ContextTest do
  use ExUnit.Case
  use Phoenix.ConnTest

  import Surface
  import ComponentTestHelper

  setup_all do
    Endpoint.start_link()
    :ok
  end

  defmodule Outer do
    use Surface.Component

    context :set, field, :any

    def init_context(assigns) do
      {:ok, field: assigns.field}
    end

    def render(assigns) do
      ~H"""
      <div>{{ @inner_content.() }}</div>
      """
    end
  end

  defmodule RenderContext do
    use Surface.Component

    def render(assigns) do
      ~H"""
      Context: {{ inspect(context) }}
      """
    end

  end

  defmodule Inner do
    use Surface.Component

    context :get, field, from: Outer

    def render(assigns) do
      ~H"""
      <span>{{ @field }}</span>
      """
    end
  end

  defmodule InnerWithOptionAs do
    use Surface.Component

    context :get, field, from: Outer, as: :my_field

    def render(assigns) do
      ~H"""
      <span>{{ @my_field }}</span>
      """
    end
  end

  defmodule InnerWrapper do
    use Surface.Component

    def render(assigns) do
      ~H"""
      <Inner />
      """
    end
  end

  test "pass context to child component" do
    code =
      """
      <Outer field="My field">
        <Inner/>
      </Outer>
      """

    assert render_live(code) =~ """
    <div><span>My field</span></div>
    """
  end

  test "pass context to child component using :as option" do
    code =
      """
      <Outer field="My field">
        <InnerWithOptionAs/>
      </Outer>
      """

    assert render_live(code) =~ """
    <div><span>My field</span></div>
    """
  end

  test "pass context down the tree of components" do
    code =
      """
      <Outer field="My field">
        <InnerWrapper />
      </Outer>
      """

    assert render_live(code) =~ """
    <div><span>My field</span></div>
    """
  end

  test "reset context after the component" do
    code =
      """
      <Outer field="My field">
        <Inner/>
      </Outer>
      <RenderContext/>
      """

    assert render_live(code) =~ """
    Context: %{}
    """
  end
end
