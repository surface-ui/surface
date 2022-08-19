defmodule Surface.SlotChangeTrackingTest do
  use ExUnit.Case, async: true

  import Phoenix.ConnTest
  import Phoenix.LiveViewTest

  @endpoint Endpoint

  defmodule Outer do
    use Surface.LiveComponent

    slot default, arg: %{param: :string}

    def render(assigns) do
      ~F"""
      <div><#slot {@default, param: "Param from Outer"}/></div>
      """
    end
  end

  defmodule ViewComponentWithInnerContent do
    use Surface.LiveView
    alias Surface.CheckUpdated

    data count, :integer, default: 0
    data test_pid, :integer

    def mount(_params, %{"test_pid" => test_pid}, socket) do
      {:ok, assign(socket, test_pid: test_pid)}
    end

    def render(assigns) do
      ~F"""
      <Outer id="outer" :let={param: param}>
        Count: {@count}
        <CheckUpdated id="1" dest={@test_pid} content={param} />
        <CheckUpdated id="2" dest={@test_pid} />
      </Outer>
      """
    end

    def handle_event("update_count", _, socket) do
      {:noreply, update(socket, :count, &(&1 + 1))}
    end
  end

  defmodule Counter do
    use Surface.LiveComponent

    slot default, arg: %{value: :integer}

    data value, :integer, default: 0

    def render(assigns) do
      ~F"""
      <div>
        Value in the Counter: {@value}
        <#slot {@default, value: @value}/>
        <button id="incButton" :on-click="inc">+</button>
      </div>
      """
    end

    def handle_event("inc", _, socket) do
      {:noreply, update(socket, :value, &(&1 + 1))}
    end
  end

  defmodule ViewWithCounter do
    use Surface.LiveView

    def render(assigns) do
      ~F"""
      <Counter id="counter" :let={value: value}>
        Value in the View: {value}
      </Counter>
      """
    end
  end

  test "changing a slot arg updates any view/component using it" do
    {:ok, view, html} = live_isolated(build_conn(), ViewWithCounter)

    assert html =~ "Value in the Counter: 0"
    assert html =~ "Value in the View: 0"

    html =
      view
      |> element("#incButton", "+")
      |> render_click()

    assert html =~ "Value in the Counter: 1"
    assert html =~ "Value in the View: 1"
  end

  test "change tracking is disabled if a child component uses a passed slot arg" do
    {:ok, view, html} =
      live_isolated(build_conn(), ViewComponentWithInnerContent, session: %{"test_pid" => self()})

    assert html =~ "Count: 0"
    assert_receive {:updated, "1"}
    assert_receive {:updated, "2"}
    refute_receive {:updated, _}

    html = render_click(view, :update_count)

    assert html =~ "Count: 1"

    # Component using slot arg should be updated
    assert_receive {:updated, "1"}

    # Component not using the slot arg should not be updated
    refute_receive {:updated, "2"}
  end
end
