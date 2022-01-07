defmodule Surface.ComponentChangeTrackingTest do
  use ExUnit.Case, async: true

  import Phoenix.ConnTest
  import Phoenix.LiveViewTest

  @endpoint Endpoint

  defmodule Comp do
    use Surface.Component

    prop id, :string, required: true

    prop value, :integer, default: 0

    def render(assigns) do
      ~F"""
      Component {@id}, Value: {@value}, Rendering: {:erlang.unique_integer([:positive])}
      """
    end
  end

  defmodule View do
    use Surface.LiveView

    data count_1, :integer, default: 0
    data count_2, :integer, default: 0

    def render(assigns) do
      ~F"""
      <Comp id="comp_1" value={@count_1}/>
      <Comp id="comp_2" value={@count_2}/>
      """
    end

    def handle_event("update_count", %{"comp" => id, "value" => value}, socket) do
      {:noreply, assign(socket, String.to_atom("count_#{id}"), value)}
    end
  end

  test "change tracking" do
    # Initial values

    {:ok, view, html} = live_isolated(build_conn(), View)
    result_1 = parse_result(html)
    assert result_1["comp_1"].value == 0
    assert result_1["comp_2"].value == 0

    # Don't rerender components if their props haven't changed

    html = render_click(view, :update_count, %{comp: "1", value: 0})
    assert parse_result(html) == result_1
    html = render_click(view, :update_count, %{comp: "2", value: 0})
    assert parse_result(html) == result_1

    # Only rerender components with changed props

    html = render_click(view, :update_count, %{comp: "1", value: 1})
    result_3 = parse_result(html)
    assert result_3["comp_1"].value == 1
    assert result_3["comp_2"] == result_1["comp_2"]

    html = render_click(view, :update_count, %{comp: "2", value: 1})
    result_4 = parse_result(html)
    assert result_4["comp_1"] == result_3["comp_1"]
    assert result_4["comp_2"].value == 1
  end

  defp parse_result(html) do
    mapper = fn [_, id, value, rendering] ->
      {id, %{value: String.to_integer(value), rendering: String.to_integer(rendering)}}
    end

    Regex.scan(~r/Component (.+?), Value: (\d+), Rendering: (\d+)/, html) |> Map.new(mapper)
  end
end
