defmodule ComponentTest do
  use ExUnit.Case
  import ComponentTestHelper
  import Surface.Component
  import Surface.BaseComponent

  defmodule Stateless do
    use Surface.Component

    property label, :string, default: ""
    property class, :css_class

    def render(assigns) do
      ~H"""
      <div class={{ @class }}>
        <span>{{ @label }}</span>
      </div>
      """
    end
  end

  defmodule Outer do
    use Surface.Component

    def render(assigns) do
      ~H"""
      <div>{{ @content }}</div>
      """
    end
  end

  defmodule Inner do
    use Surface.Component

    def render(assigns) do
      ~H"""
      <span>Inner</span>
      """
    end
  end

  test "render stateless component" do
    assigns = %{}
    code =
      ~H"""
      <Stateless label="My label" class="myclass"/>
      """

    assert render_surface(code) =~ """
    <div class="myclass">
      <span>My label</span>
    </div>
    """
  end

  test "render nested component's content" do
    assigns = %{}
    code =
      ~H"""
      <Outer>
        <Inner/>
      </Outer>
      """

    assert render_surface(code) =~ """
    <div>
      <span>Inner</span>
    </div>
    """
  end
end

