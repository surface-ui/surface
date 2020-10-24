defmodule Surface.ComponentTest do
  use ExUnit.Case, async: true
  import Phoenix.ConnTest

  import Phoenix.LiveViewTest
  import Surface
  import ComponentTestHelper

  @endpoint Endpoint

  defmodule Stateless do
    use Surface.Component

    prop label, :string, default: ""
    prop class, :css_class

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
      <div><slot/></div>
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

  defmodule OuterWithSlotProps do
    use Surface.Component

    slot default, props: [:info]

    def render(assigns) do
      info = "My info"

      ~H"""
      <div><slot :props={{ info: info }}/></div>
      """
    end
  end

  defmodule ViewWithStateless do
    use Surface.LiveView

    def render(assigns) do
      ~H"""
      <Stateless label="My label" class="myclass"/>
      """
    end
  end

  defmodule ViewWithNested do
    use Surface.LiveView

    def render(assigns) do
      ~H"""
      <Outer>
        <Inner/>
      </Outer>
      """
    end
  end

  defmodule ViewWithSlotProps do
    use Surface.LiveView

    def render(assigns) do
      ~H"""
      <OuterWithSlotProps :let={{ info: my_info }}>
        {{ my_info }}
      </OuterWithSlotProps>
      """
    end
  end

  test "raise compile error if option :slot is not a string" do
    id = :erlang.unique_integer([:positive]) |> to_string()
    module = "TestSlotWithoutSlotName_#{id}"

    code = """
    defmodule #{module} do
      use Surface.Component, slot: {1, 2}

      prop label, :string
    end
    """

    message = "code.exs:2: invalid value for option :slot. Expected a string, got: {1, 2}"

    assert_raise(CompileError, message, fn ->
      {{:module, _, _, _}, _} = Code.eval_string(code, [], %{__ENV__ | file: "code.exs", line: 1})
    end)
  end

  describe "With LiveView" do
    test "render stateless component" do
      {:ok, _view, html} = live_isolated(build_conn(), ViewWithStateless)

      assert_html(
        html =~ """
        <div class="myclass">
          <span>My label</span>
        </div>
        """
      )
    end

    test "render nested component's content" do
      {:ok, _view, html} = live_isolated(build_conn(), ViewWithNested)

      assert_html(
        html =~ """
        <div>
          <span>Inner</span>
        </div>
        """
      )
    end

    test "render content with slot props" do
      {:ok, _view, html} = live_isolated(build_conn(), ViewWithSlotProps)

      assert_html(
        html =~ """
        <div>
          My info
        </div>
        """
      )
    end
  end

  describe "Without LiveView" do
    test "render stateless component" do
      code =
        quote do
          ~H"""
          <Stateless label="My label" class="myclass"/>
          """
        end

      assert render_live(code) =~ """
             <div class="myclass"><span>My label</span></div>
             """
    end

    test "render nested component's content" do
      code =
        quote do
          ~H"""
          <Outer>
            <Inner/>
          </Outer>
          """
        end

      assert render_live(code) =~ """
             <div><span>Inner</span></div>
             """
    end

    test "render content with slot props" do
      code =
        quote do
          ~H"""
          <OuterWithSlotProps :let={{ info: my_info }}>
            {{ my_info }}
          </OuterWithSlotProps>
          """
        end

      assert render_live(code) =~ """
             <div>
               My info
             </div>
             """
    end

    test "render stateless component without named slots with render_component/2" do
      assert render_component(Stateless, %{label: "My label", class: "myclass"}) =~ """
             <div class="myclass">
               <span>My label</span>
             </div>
             """
    end

    test "render error message if module is not a component" do
      import ExUnit.CaptureIO

      code =
        quote do
          ~H"""
          <div>
            <Enum/>
          </div>
          """
        end

      output =
        capture_io(:standard_error, fn ->
          assert render_live(code) =~ """
                 <div><span style="color: red; border: 2px solid red; padding: 3px"> \
                 Error: cannot render &lt;Enum&gt; (module Enum is not a component)\
                 </span></div>
                 """
        end)

      assert output =~ ~r"""
             cannot render <Enum> \(module Enum is not a component\)
               code:2:\
             """
    end
  end
end
