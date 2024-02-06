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

  defmodule PhoenixFunctionComponent do
    use Phoenix.Component

    def show(assigns) do
      ~H"""
      <div class={@class}>
        <span><%= @label %></span>
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

  defmodule OuterWithSlotArg do
    use Surface.Component

    slot default, arg: %{info: :string}

    def render(assigns) do
      info = "My info"

      ~F"""
      <div><#slot {@default, info: info}/></div>
      """
    end
  end

  defmodule ViewWithStateless do
    use Surface.LiveView

    def render(assigns) do
      ~F"""
      <Component module={Stateless} label="My label" class="myclass"/>
      """
    end
  end

  defmodule ViewWithPhoenixFunctionComponent do
    use Surface.LiveView

    def render(assigns) do
      ~F"""
      <Component module={PhoenixFunctionComponent} function={:show} label="My label" class="myclass"/>
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

  defmodule ViewWithSlotArg do
    use Surface.LiveView

    def render(assigns) do
      ~F"""
      <Component module={OuterWithSlotArg} :let={info: my_info}>
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
      ~F"""
      <Component module={StatelessWithId} id="my_id" />
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

    test "render content with slot arg" do
      {:ok, _view, html} = live_isolated(build_conn(), ViewWithSlotArg)

      assert html =~ """
             <div>
               My info
             </div>\
             """
    end

    test "render phoenix function component" do
      {:ok, _view, html} = live_isolated(build_conn(), ViewWithPhoenixFunctionComponent)

      assert html =~ """
             <div class="myclass"><span>My label</span></div>\
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

    test "render content with slot arg" do
      html =
        render_surface do
          ~F"""
          <Component module={OuterWithSlotArg} :let={info: my_info}>
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

    register_propagate_context_to_slots([__MODULE__.ContextComp])

    defmodule ContextComp do
      use Surface.Component

      slot default

      data form, :form

      def render(assigns) do
        assigns = Context.copy_assign(assigns, :form)

        ~F"""
        <Context put={field: "#{@form} + field"}>
          <#slot/>
        </Context>
        """
      end
    end

    test "context propagation" do
      alias Surface.Components.Context

      html =
        render_surface do
          ~F"""
          <Context put={form: :fake_form}>
            <Component module={ContextComp}>
              <Context get={field: field}>
                {field}
              </Context>
            </Component>
          </Context>
          """
        end

      assert html =~ "fake_form + field"
    end

    test "render plain old phoenix function component" do
      html =
        render_surface do
          ~F"""
          <Component module={PhoenixFunctionComponent} function={:show} label="My label" class="myclass"/>
          """
        end

      assert html =~ """
             <div class="myclass">
               <span>My label</span>
             </div>
             """
    end

    test "renders the last attribute when passing multiple that don't accumulate, and warns" do
      output =
        capture_io(:standard_error, fn ->
          html =
            render_surface do
              ~F"""
              <Component module={Stateless} label="My label 1" label="My label 2" />
              """
            end

          assert html =~ """
                 <div>
                   <span>My label 2</span>
                 </div>
                 """
        end)

      assert output =~ """
             the prop `label` has been passed multiple times. Considering only the last value.

             Hint: Either remove all redundant definitions or set option `accumulate` to `true`:

             ```
               prop label, :string, accumulate: true
             ```

             This way the values will be accumulated in a list.
             """
    end

    test "renders the last attribute when passing multiple that don't accumulate, with assign" do
      assigns = %{label1: "My label 1", label2: "My label 2"}

      output =
        capture_io(:standard_error, fn ->
          html =
            render_surface do
              ~F"""
              <Component module={Stateless} label={@label1} label={@label2} />
              """
            end

          assert html =~ """
                 <div>
                   <span>My label 2</span>
                 </div>
                 """
        end)

      assert output =~ """
             the prop `label` has been passed multiple times. Considering only the last value.

             Hint: Either remove all redundant definitions or set option `accumulate` to `true`:

             ```
               prop label, :string, accumulate: true
             ```

             This way the values will be accumulated in a list.
             """
    end

    test "attribute values are still converted according to their types but only at runtime" do
      html =
        render_surface do
          ~F"""
          <Component module={ComponentWithEvent} click={"ok", target: "#comp"}/>
          """
        end

      doc = parse_document!(html)

      assert js_attribute(doc, "phx-click") == [["push", %{"event" => "ok", "target" => "#comp"}]]
    end
  end

  describe "dynamic components in dead views" do
    defmodule DeadView do
      use Phoenix.Template, root: "support/dead_views"
      import Surface
      alias Surface.Components.Dynamic.Component

      def render("index.html", assigns) do
        ~F"""
        <Component module={Outer}><Component module={Stateless} label="My label" class="myclass"/></Component>
        """
      end
    end

    test "renders dynamic components" do
      assert Phoenix.Template.render_to_string(DeadView, "index", "html", []) =~
               """
               <div><div class="myclass">
                 <span>My label</span>
               </div>
               </div>
               """
    end
  end
end
