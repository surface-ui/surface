defmodule Surface.Components.EventsTest do
  use Surface.ConnCase, async: true

  defmodule ComponentWithEvents do
    use Surface.Component
    use Surface.Components.Events

    import Surface.Components.Utils, only: [events_to_opts: 1]

    def render(assigns) do
      attrs = events_to_opts(assigns)

      ~F"""
      <div :attrs={attrs} />
      """
    end

    def mount(_params, session, socket) do
      {:ok, assign(socket, changeset: session["changeset"])}
    end
  end

  defmodule Parent do
    use Surface.LiveComponent

    def render(assigns) do
      ~F"""
      <div>
        <ComponentWithEvents click="my_click" />
      </div>
      """
    end

    def handle_event(_, _, socket) do
      {:noreply, socket}
    end
  end

  test "capture click event with parent live view as target" do
    html =
      render_surface do
        ~F"""
        <ComponentWithEvents capture_click="my_click" />
        """
      end

    assert html =~ """
           <div phx-capture-click="my_click"></div>
           """
  end

  test "click event with parent live view as target" do
    html =
      render_surface do
        ~F"""
        <ComponentWithEvents click="my_click" />
        """
      end

    assert html =~ """
           <div phx-click="my_click"></div>
           """
  end

  test "window focus event with parent live view as target" do
    html =
      render_surface do
        ~F"""
        <ComponentWithEvents window_focus="my_focus" />
        """
      end

    assert html =~ """
           <div phx-window-focus="my_focus"></div>
           """
  end

  test "window blur event with parent live view as target" do
    html =
      render_surface do
        ~F"""
        <ComponentWithEvents window_blur="my_blur" />
        """
      end

    assert html =~ """
           <div phx-window-blur="my_blur"></div>
           """
  end

  test "focus event with parent live view as target" do
    html =
      render_surface do
        ~F"""
        <ComponentWithEvents focus="my_focus" />
        """
      end

    assert html =~ """
           <div phx-focus="my_focus"></div>
           """
  end

  test "blur event with parent live view as target" do
    html =
      render_surface do
        ~F"""
        <ComponentWithEvents blur="my_blur" />
        """
      end

    assert html =~ """
           <div phx-blur="my_blur"></div>
           """
  end

  test "window keyup event with parent live view as target" do
    html =
      render_surface do
        ~F"""
        <ComponentWithEvents window_keyup="my_keyup" />
        """
      end

    assert html =~ """
           <div phx-window-keyup="my_keyup"></div>
           """
  end

  test "window keydown event with parent live view as target" do
    html =
      render_surface do
        ~F"""
        <ComponentWithEvents window_keydown="my_keydown" />
        """
      end

    assert html =~ """
           <div phx-window-keydown="my_keydown"></div>
           """
  end

  test "keyup event with parent live view as target" do
    html =
      render_surface do
        ~F"""
        <ComponentWithEvents keyup="my_keyup" />
        """
      end

    assert html =~ """
           <div phx-keyup="my_keyup"></div>
           """
  end

  test "keydown event with parent live view as target" do
    html =
      render_surface do
        ~F"""
        <ComponentWithEvents keydown="my_keydown" />
        """
      end

    assert html =~ """
           <div phx-keydown="my_keydown"></div>
           """
  end

  test "click event with @myself as target" do
    html =
      render_surface do
        ~F"""
        <Parent id="comp" />
        """
      end

    event = Phoenix.HTML.Engine.html_escape(~S([["push",{"event":"my_click","target":1}]]))

    assert html =~ """
           <div>
             <div phx-click="#{event}"></div>
           </div>
           """
  end

  test "event with values" do
    html =
      render_surface do
        ~F"""
        <ComponentWithEvents click="my_click" values={ hello: :world, foo: "bar", one: 2 } />
        """
      end

    assert html =~ """
           <div phx-click="my_click" phx-value-foo="bar" phx-value-hello="world" phx-value-one="2"></div>
           """
  end
end
