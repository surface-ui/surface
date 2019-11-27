defmodule Surface.DirectivesTest do
  use ExUnit.Case
  use Phoenix.ConnTest

  import ComponentTestHelper
  import Surface.Component, only: [component: 2]
  import Surface.Properties, only: [put_default_props: 2]
  import Surface.Translator, only: [sigil_H: 2]

  defmodule Div do
    use Surface.Component

    def render(assigns) do
      ~H"""
      <div>{{ @inner_content.([]) }}</div>
      """
    end
  end

  describe ":for" do
    test "in components" do
      assigns = %{items: [1, 2]}
      code =
        ~H"""
        <Div :for={{ i <- @items }}>
          Item: {{i}}
        </Div>
        """

      assert render_surface(code) =~ """
      <div>
        Item: 1
      </div>
      <div>
        Item: 2
      </div>
      """
    end

    test "in html tags" do
      assigns = %{items: [1, 2]}
      code =
        ~H"""
        <div :for={{ i <- @items }}>
          Item: {{i}}
        </div>
        """

      assert render_surface(code) =~ """
      <div>
        Item: 1
      </div><div>
        Item: 2
      </div>
      """
    end
  end

  describe ":if" do
    test "in components" do
      assigns = %{show: true, dont_show: false}
      code =
        ~H"""
        <Div :if={{ @show }}>
          Show
        </Div>
        <Div :if={{ @dont_show }}>
          Dont's show
        </Div>
        """

      assert render_surface(code) == """
      <div>
        Show
      </div>
      """
    end

    test "in html tags" do
      assigns = %{show: true, dont_show: false}
      code =
        ~H"""
        <div :if={{ @show }}>
          Show
        </div>
        <div :if={{ @dont_show }}>
          Dont's show
        </div>
        """

      assert render_surface(code) =~ """
      <div>
        Show
      </div>
      """
    end
  end
end

