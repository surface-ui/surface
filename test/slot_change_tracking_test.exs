defmodule Surface.SlotChangeTrackingTest do
  use ExUnit.Case, async: true

  import Phoenix.ConnTest
  import Phoenix.LiveViewTest

  @endpoint Endpoint

  defmodule Outer do
    use Surface.LiveComponent

    slot default, props: [:param]

    def render(assigns) do
      ~H"""
      <div><slot :props={{ param: "Param from Outer" }}/></div>
      """
    end
  end

  defmodule ViewComponentWithInnerContent do
    use Surface.LiveView
    alias Surface.CheckUpdated

    data count, :integer, default: 0

    def mount(_params, %{"test_pid" => test_pid}, socket) do
      {:ok, assign(socket, test_pid: test_pid)}
    end

    def render(assigns) do
      ~H"""
      <Outer id="outer" :let={{ :param }}>
        Count: {{ @count }}
        <CheckUpdated id="1" dest={{ @test_pid }} content={{ @param }} />
        <CheckUpdated id="2" dest={{ @test_pid }} />
      </Outer>
      """
    end

    def handle_event("update_count", _, socket) do
      {:noreply, update(socket, :count, &(&1 + 1))}
    end
  end

  test "change tracking is disabled if a child component uses a passed slot prop" do
    {:ok, view, html} =
      live_isolated(build_conn(), ViewComponentWithInnerContent, session: %{"test_pid" => self()})

    assert html =~ "Count: 0"
    assert_receive {:updated, "1"}
    assert_receive {:updated, "2"}
    refute_receive {:updated, _}

    html = render_click(view, :update_count)

    assert html =~ "Count: 1"

    # Component using slot props should be updated
    assert_receive {:updated, "1"}

    # Component not using the slot props should not be updated
    refute_receive {:updated, "2"}
  end
end
