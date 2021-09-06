defmodule Surface.Components.Dynamic.ComponentTest do
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
      module = Stateless

      ~F"""
      <Component module={module} label="My label" class="myclass"/>
      """
    end
  end

  defmodule ViewWithNested do
    use Surface.LiveView

    def render(assigns) do
      ~F"""
      <Component module={Outer}>
        <Component module={Inner}/>
      </Component>
      """
    end
  end

  defmodule ViewWithSlotArgs do
    use Surface.LiveView

    def render(assigns) do
      ~F"""
      <Component module={OuterWithSlotArgs} :let={info: my_info}>
        {my_info}
      </Component>
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

    defp update(assigns) do
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
      module = StatelessWithId

      ~F"""
      <Component module={module} id="my_id" />
      """
    end
  end

  defmodule ViewWithStatelessWithIdAndUpdate do
    use Surface.LiveView

    def render(assigns) do
      ~F"""
      <Component module={StatelessWithIdAndUpdate} id="my_id" />
      """
    end
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
    alias Surface.Components.Dynamic.Component

    test "render stateless component" do
      html =
        render_surface do
          ~F"""
          <Component module={Stateless} label="My label" class="myclass"/>
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
          <Component module={Outer}>
            <Component module={Inner}/>
          </Component>
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
          <Component module={OuterWithSlotArgs} :let={info: my_info}>
            {my_info}
          </Component>
          """
        end

      assert html =~ """
             <div>
               My info
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

  describe "dynamic components in dead views" do
    defmodule DeadView do
      use Phoenix.View, root: "support/dead_views"
      import Surface
      alias Surface.Components.Dynamic.Component

      def render("index.html", assigns) do
        ~F"""
        <Component module={Outer}><Component module={Stateless} label="My label" class="myclass"/></Component>
        """
      end
    end

    test "renders dynamic components" do
      assert Phoenix.View.render_to_string(DeadView, "index.html", []) =~
               """
               <div><div class="myclass">
                 <span>My label</span>
               </div>
               </div>
               """
    end
  end
end
