defmodule LiveComponentChangeTrackingTest do
  use ExUnit.Case, async: true

  import Phoenix.ConnTest
  import Phoenix.LiveViewTest

  @endpoint Endpoint

  defmodule CheckUpdated do
    use Surface.LiveComponent

    @doc "The process to send the :updated message"
    property dest, :any, required: true

    @doc "Something to inspect"
    property content, :any, default: %{}

    def update(assigns, socket) do
      if connected?(socket) do
        send(assigns.dest, :updated)
      end

      {:ok, assign(socket, assigns)}
    end

    def render(assigns) do
      ~H"""
      <div>{{ inspect(@content) }}</div>
      """
    end
  end

  defmodule ViewPassingAssignsMap do
    use Surface.LiveView

    data count, :integer, default: 0

    def mount(_params, %{"test_pid" => test_pid}, socket) do
      {:ok, assign(socket, test_pid: test_pid)}
    end

    def render(assigns) do
      ~H"""
      Count: {{ @count }}
      <CheckUpdated dest={{ @test_pid }} content={{ assigns }} />
      """
    end

    def handle_event("update_count", _, socket) do
      {:noreply, update(socket, :count, &(&1 + 1))}
    end
  end

  defmodule ViewPassingDataAsProp do
    use Surface.LiveView

    data count, :integer, default: 0
    data passing_count, :integer, default: 0

    def mount(_params, %{"test_pid" => test_pid}, socket) do
      {:ok, assign(socket, test_pid: test_pid)}
    end

    def render(assigns) do
      ~H"""
      Count: {{ @count }}
      <CheckUpdated dest={{ @test_pid }} content={{ @passing_count }} />
      """
    end

    def handle_event("update_count", _, socket) do
      {:noreply, update(socket, :count, &(&1 + 1))}
    end

    def handle_event("update_passing_count", _, socket) do
      {:noreply, update(socket, :passing_count, &(&1 + 1))}
    end
  end

  test "passing the `assigns` map directly disables per-assign change tracking" do
    {:ok, view, html} =
      live_isolated(build_conn(), ViewPassingAssignsMap, session: %{"test_pid" => self()})

    assert_receive :updated
    assert html =~ "Count: 0"

    html = render_click(view, :update_count)
    assert html =~ "Count: 1"
    assert_receive :updated
  end

  test "passing data as props works with change tracking" do
    {:ok, view, html} =
      live_isolated(build_conn(), ViewPassingDataAsProp, session: %{"test_pid" => self()})

    assert_receive :updated
    assert html =~ "Count: 0"

    # Don't update the component if changed assigns are not passed as props
    html = render_click(view, :update_count)
    assert html =~ "Count: 1"
    refute_receive :updated

    # Update the component if changed assigns are passed as props
    html = render_click(view, :update_passing_count)
    assert html =~ "Count: 1"
    assert_receive :updated
  end
end
