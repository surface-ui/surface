defmodule Surface.Components.Dynamic.ComponentTest do
  use Surface.ConnCase, async: true

  import Phoenix.ConnTest
  import ExUnit.CaptureIO

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

  defmodule ComponentWithEvent do
    use Surface.Component

    prop click, :event

    def render(assigns) do
      ~F"""
      <div :on-click={@click}/>
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

    test "attribute values are still converted according to their types but only at runtime" do
      html =
        render_surface do
          ~F"""
          <Component module={ComponentWithEvent} click={"ok", target: "#comp"}/>
          """
        end

      event = Phoenix.HTML.Engine.html_escape(~S([["push",{"event":"ok","target":"#comp"}]]))

      assert html =~ """
             <div phx-click="#{event}"></div>
             """
    end

    test "at runtime, warn on unknown attributes at the component definition's file/line " do
      file = Path.relative_to_cwd(__ENV__.file)
      line = __ENV__.line + 8

      output =
        capture_io(:standard_error, fn ->
          assigns = %{mod: ComponentWithEvent}

          render_surface do
            ~F"""
            <Component
              module={@mod}
              unknown_attr="123"
            />
            """
          end
        end)

      assert output =~ ~r"""
             Unknown property "unknown_attr" for component <Surface.Components.Dynamic.ComponentTest.ComponentWithEvent>
               #{file}:#{line}: Surface.Components.Dynamic.ComponentTest \(module\)\
             """
    end

    test "at runtime, warn on unknown attributes as expr at the component definition's file/line " do
      file = Path.relative_to_cwd(__ENV__.file)
      line = __ENV__.line + 8

      output =
        capture_io(:standard_error, fn ->
          assigns = %{mod: ComponentWithEvent, var: 123}

          render_surface do
            ~F"""
            <Component
              module={@mod}
              unknown_attr={@var}
            />
            """
          end
        end)

      assert output =~ ~r"""
             Unknown property "unknown_attr" for component <Surface.Components.Dynamic.ComponentTest.ComponentWithEvent>
               #{file}:#{line}: Surface.Components.Dynamic.ComponentTest \(module\)\
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
