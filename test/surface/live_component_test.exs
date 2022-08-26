defmodule Surface.LiveComponentTest do
  use Surface.ConnCase, async: true

  defmodule StatelessComponent do
    use Surface.Component

    prop label, :string

    def render(assigns) do
      ~F"""
      <div phx-click="click">{@label}</div>
      """
    end
  end

  defmodule StatefulComponent do
    use Surface.LiveComponent

    data label, :string, default: "Initial stateful"
    data assigned_in_update, :any

    def update(_assigns, socket) do
      {:ok, assign(socket, assigned_in_update: "Assigned in update/2")}
    end

    def render(assigns) do
      ~F"""
      <div :on-click="click" id="theDiv">{@label} - {@assigned_in_update}</div>
      """
    end

    def handle_event("click", _, socket) do
      {:noreply, assign(socket, label: "Updated stateful")}
    end
  end

  defmodule View do
    use Surface.LiveView

    data label, :string, default: "Initial stateless"

    def render(assigns) do
      ~F"""
      <StatelessComponent label={@label} />
      <StatefulComponent id="comp" />
      """
    end

    def handle_event("click", _, socket) do
      {:noreply, assign(socket, label: "Updated stateless")}
    end
  end

  defmodule InfoProvider do
    use Surface.Component

    slot default, arg: %{info: :string}

    def render(assigns) do
      info = "Hi there!"

      ~F"""
      <div>
        <#slot {@default, info: info}/>
      </div>
      """
    end
  end

  defmodule InfoProviderWithoutSlotArg do
    use Surface.Component

    slot default

    def render(assigns) do
      ~F"""
      <div>
        <#slot/>
      </div>
      """
    end
  end

  defmodule LiveComponentWithEvent do
    use Surface.LiveComponent

    prop event, :event

    def render(assigns) do
      ~F"""
      <button :on-click={@event} />
      """
    end
  end

  defmodule LiveComponentDataWithoutDefault do
    use Surface.LiveComponent

    data count, :integer

    def render(assigns) do
      ~F"""
      <div>{Map.has_key?(assigns, :count)}</div>
      """
    end
  end

  test "render content without slot arg" do
    html =
      render_surface do
        ~F"""
        <InfoProviderWithoutSlotArg>
          <span>Hi there!</span>
        </InfoProviderWithoutSlotArg>
        """
      end

    assert html =~ """
           <div>
             <span>Hi there!</span>
           </div>
           """
  end

  test "render content with slot arg" do
    html =
      render_surface do
        ~F"""
        <InfoProvider :let={info: my_info}>
          <span>{my_info}</span>
        </InfoProvider>
        """
      end

    assert html =~ """
           <div>
             <span>Hi there!</span>
           </div>
           """
  end

  test "render stateful component with event" do
    html =
      render_surface do
        ~F"""
        <LiveComponentWithEvent event="click-event" id="button" />
        """
      end

    assert html =~ """
           <button phx-click=\"click-event\"></button>
           """
  end

  test "do not set assign for `data` without default value" do
    html =
      render_surface do
        ~F"""
        <LiveComponentDataWithoutDefault id="counter"/>
        """
      end

    assert html =~ "false"
  end

  test "render stateless component" do
    {:ok, _view, html} = live_isolated(build_conn(), View)
    assert html =~ "Initial stateless"
  end

  test "handle events in stateless component (handled by the live view)" do
    {:ok, view, _html} = live_isolated(build_conn(), View)
    assert render_click(view, :click) =~ "Updated stateless"
  end

  test "render LiveComponent" do
    {:ok, _view, html} = live_isolated(build_conn(), View)
    assert html =~ "Initial stateful"
  end

  test "render data assigned in update/2" do
    {:ok, _view, html} = live_isolated(build_conn(), View)
    assert html =~ "Assigned in update/2"
  end

  test "handle events in LiveComponent (handled by the component itself)" do
    {:ok, view, _html} = live_isolated(build_conn(), View)
    assert render_click(element(view, "#theDiv")) =~ "Updated stateful"
  end
end
