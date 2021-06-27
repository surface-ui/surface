defmodule Surface.ComponentTest do
  use Surface.ConnCase, async: true
  import Phoenix.ConnTest

  defmodule Stateless do
    use Surface.Component

    prop label, :string, default: ""
    prop class, :css_class

    def render(assigns) do
      ~F"""
      <div class={@class}>
        <span>{@label}</span>
      </div>
      """
    end
  end

  defmodule Outer do
    use Surface.Component

    slot default

    def render(assigns) do
      ~F"""
      <div><#slot/></div>
      """
    end
  end

  defmodule Inner do
    use Surface.Component

    def render(assigns) do
      ~F"""
      <span>Inner</span>
      """
    end
  end

  defmodule OuterWithSlotArgs do
    use Surface.Component

    slot default, args: [:info]

    def render(assigns) do
      info = "My info"

      ~F"""
      <div><#slot :args={info: info}/></div>
      """
    end
  end

  defmodule ViewWithStateless do
    use Surface.LiveView

    def render(assigns) do
      ~F"""
      <Stateless label="My label" class="myclass"/>
      """
    end
  end

  defmodule ViewWithNested do
    use Surface.LiveView

    def render(assigns) do
      ~F"""
      <Outer>
        <Inner/>
      </Outer>
      """
    end
  end

  defmodule ViewWithSlotArgs do
    use Surface.LiveView

    def render(assigns) do
      ~F"""
      <OuterWithSlotArgs :let={info: my_info}>
        {my_info}
      </OuterWithSlotArgs>
      """
    end
  end

  defmodule StatelessWithId do
    use Surface.Component

    prop id, :string

    def render(assigns) do
      ~F"""
      <div>{@id}</div>
      """
    end
  end

  defmodule StatelessWithIdAndUpdate do
    use Surface.Component

    prop id, :string
    data id_copy, :string

    def update(assigns) do
      assign(assigns, :id_copy, assigns.id)
    end

    @impl true
    def render(assigns) do
      assigns = update(assigns)

      ~F"""
      <div>{@id} - {@id_copy}</div>
      """
    end
  end

  defmodule ViewWithStatelessWithId do
    use Surface.LiveView

    def render(assigns) do
      ~F"""
      <StatelessWithId id="my_id" />
      """
    end
  end

  defmodule ViewWithStatelessWithIdAndUpdate do
    use Surface.LiveView

    def render(assigns) do
      ~F"""
      <StatelessWithIdAndUpdate id="my_id" />
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

      assert html =~ """
             <div class="myclass"><span>My label</span></div>\
             """
    end

    test "stateless component with id should not become stateful" do
      {:ok, _view, html} = live_isolated(build_conn(), ViewWithStatelessWithId)

      # Stateful components are rendered as <div data-phx-component="...">
      assert html =~ """
             <div>my_id</div>\
             """
    end

    test "stateless component with id and implementing update/2 should not become stateful" do
      {:ok, _view, html} = live_isolated(build_conn(), ViewWithStatelessWithIdAndUpdate)

      # Stateful components are rendered as <div data-phx-component="...">
      assert html =~ """
             <div>my_id - my_id</div>\
             """
    end

    test "render nested component's content" do
      {:ok, _view, html} = live_isolated(build_conn(), ViewWithNested)

      assert html =~ """
             <div><span>Inner</span></div>\
             """
    end

    test "render content with slot args" do
      {:ok, _view, html} = live_isolated(build_conn(), ViewWithSlotArgs)

      assert html =~ """
             <div>
               My info
             </div>\
             """
    end
  end

  describe "Without LiveView" do
    test "render stateless component" do
      html =
        render_surface do
          ~F"""
          <Stateless label="My label" class="myclass"/>
          """
        end

      assert html =~ """
             <div class="myclass">
               <span>My label</span>
             </div>
             """
    end

    test "render nested component's content" do
      html =
        render_surface do
          ~F"""
          <Outer>
            <Inner/>
          </Outer>
          """
        end

      assert html =~ """
             <div>
               <span>Inner</span>
             </div>
             """
    end

    test "render content with slot args" do
      html =
        render_surface do
          ~F"""
          <OuterWithSlotArgs :let={info: my_info}>
            {my_info}
          </OuterWithSlotArgs>
          """
        end

      assert html =~ """
             <div>
               My info
             </div>
             """
    end

    test "render stateless component without named slots with render_component/2" do
      html =
        render_surface do
          ~F"""
          <Stateless label="My label" class="myclass"/>
          """
        end

      assert html =~ """
             <div class="myclass">
               <span>My label</span>
             </div>
             """
    end

    test "render error message if module is not a component", %{conn: conn} do
      import ExUnit.CaptureIO

      code =
        quote do
          ~F"""
          <div>
            <Enum/>
          </div>
          """
        end

      output =
        capture_io(:standard_error, fn ->
          module = compile_surface(code)
          {:ok, _view, html} = live_isolated(conn, module)

          assert html =~ """
                 <div><span style="color: red; border: 2px solid red; padding: 3px"> \
                 Error: cannot render &lt;Enum&gt; (module Enum is not a component)\
                 </span></div>\
                 """
        end)

      assert output =~ ~r"""
             cannot render <Enum> \(module Enum is not a component\)
               code:2:\
             """
    end
  end
end
