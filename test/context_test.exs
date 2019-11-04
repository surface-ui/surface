defmodule ContextTest do
  use ExUnit.Case
  use Phoenix.ConnTest
  import ComponentTestHelper
  import Surface.Translator, only: [sigil_H: 2]
  import Surface.BaseComponent

  defmodule Outer do
    use Surface.Component

    def begin_context(props) do
      Map.put(props.context, :field, props.field)
    end

    def render(assigns) do
      ~H"""
      <div>{{ @inner_content.([]) }}</div>
      """
    end

    def end_context(props) do
      Map.delete(props.context, :field)
    end
  end

  defmodule Inner do
    use Surface.Component

    def render(assigns) do
      ~H"""
      <span>{{ @context.field }}</span>
      """
    end
  end

  test "render context field" do
    import Surface.Component, only: [component: 2]

    assigns = %{}
    code =
      ~H"""
      <Outer field="My field">
        <Inner/>
      </Outer>
      """

    assert render_surface(code) =~ """
    <div>
      <span>My field</span>
    </div>
    """
  end
end

