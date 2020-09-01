defmodule Surface.SlotChangeTrackingTest do
  use ExUnit.Case, async: true

  import Phoenix.ConnTest
  import Phoenix.LiveViewTest

  @endpoint Endpoint

  defmodule Outer do
    use Surface.LiveComponent

    property id, :string

    slot default

    def render(assigns) do
      ~H"""
      <div>{{ @inner_content.([]) }}</div>
      """
    end
  end

  defmodule ViewComponentWithSlot do
    use Surface.LiveView
    alias Surface.CheckUpdated

    data count, :integer, default: 0

    def mount(_params, %{"test_pid" => test_pid}, socket) do
      {:ok, assign(socket, test_pid: test_pid)}
    end

    def render(assigns) do
      ~H"""
      <Outer id="outer" :debug>
        Count: {{ @count }}
        <CheckUpdated id="1" dest={{ @test_pid }} />
      </Outer>
      """
    end

    def handle_event("update_count", _, socket) do
      {:noreply, update(socket, :count, &(&1 + 1))}
    end
  end

  test "change tracking is enabled" do
    {:ok, view, html} =
      live_isolated(build_conn(), ViewComponentWithSlot, session: %{"test_pid" => self()})

    assert html =~ "Count: 0"
    assert_receive {:updated, "1"}
    refute_receive {:updated, _}

    html = render_click(view, :update_count)
    assert html =~ "Count: 1"

    # TODO: It fails! Fix it.
    # The component should not be updated
    refute_receive {:updated, "1"}
  end
end
