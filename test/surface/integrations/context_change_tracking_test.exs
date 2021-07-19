defmodule Surface.ContextChangeTrackingTest do
  use ExUnit.Case, async: true

  import Phoenix.ConnTest
  import Phoenix.LiveViewTest

  @endpoint Endpoint

  defmodule ContextSetter do
    use Surface.Component

    slot default

    def render(assigns) do
      ~F"""
      <Context put={field: "field value"}>
        <div><#slot/></div>
      </Context>
      """
    end
  end

  defmodule ContextGetter do
    use Surface.Component

    alias Surface.CheckUpdated

    prop test_pid, :any, required: true

    slot default

    def render(assigns) do
      ~F"""
      <Context get={field: field}>
        <CheckUpdated id="1" dest={@test_pid} content={field}/>
        <CheckUpdated id="2" dest={@test_pid}/>
        <div><#slot/></div>
      </Context>
      """
    end
  end

  defmodule View do
    use Surface.LiveView
    alias Surface.CheckUpdated

    data count, :integer, default: 0
    data test_pid, :integer

    def mount(_params, %{"test_pid" => test_pid}, socket) do
      {:ok, assign(socket, test_pid: test_pid)}
    end

    def render(assigns) do
      ~F"""
      <div>
        <ContextSetter>
          Count: {@count}
          <ContextGetter test_pid={@test_pid}>
            <CheckUpdated id="3" dest={@test_pid}/>
          </ContextGetter>
          <CheckUpdated id="4" dest={@test_pid}/>
        </ContextSetter>
      </div>
      """
    end

    def handle_event("update_count", _, socket) do
      {:noreply, update(socket, :count, &(&1 + 1))}
    end
  end

  test "change tracking is disabled for components using the context" do
    {:ok, view, html} = live_isolated(build_conn(), View, session: %{"test_pid" => self()})

    assert html =~ "Count: 0"
    assert_receive {:updated, "1"}
    assert_receive {:updated, "2"}
    assert_receive {:updated, "3"}
    assert_receive {:updated, "4"}
    refute_receive {:updated, _}

    html = render_click(view, :update_count)

    assert html =~ "Count: 1"
    assert html =~ "field value"

    # Component using context assings should be updated
    assert_receive {:updated, "1"}

    # TODO: Components not using the context assigns should not be updated
    # refute_receive {:updated, "2"}
    # refute_receive {:updated, "3"}
    refute_receive {:updated, "4"}
  end
end
