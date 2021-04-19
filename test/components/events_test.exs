defmodule Surface.Components.EventsTest do
  use Surface.ConnCase, async: true

  defmodule ComponentWithEvents do
    use Surface.Component
    use Surface.Components.Events

    import Surface.Components.Utils, only: [events_to_opts: 1, opts_to_attrs: 1]

    def render(assigns) do
      attrs =
        assigns
        |> events_to_opts()
        |> opts_to_attrs()

      ~H"""
      <div :attrs={{ attrs }} />
      """
    end

    def mount(_params, session, socket) do
      {:ok, assign(socket, changeset: session["changeset"])}
    end
  end

  defmodule Parent do
    use Surface.LiveComponent

    def render(assigns) do
      ~H"""
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
        ~H"""
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
        ~H"""
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
        ~H"""
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
        ~H"""
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
        ~H"""
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
        ~H"""
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
        ~H"""
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
        ~H"""
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
        ~H"""
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
        ~H"""
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
        ~H"""
        <Parent id="comp" />
        """
      end

    assert html =~ ~r"""
           <div>
             <div phx-click="my_click" phx-target="1"></div>
           </div>
           """
  end
end
