defmodule Surface.LVChangeTrackingTest do
  # A few tests using vanilla LV to reproduce different scenarios using slot arguments.
  # The main goal is to validate how using contexts in Surface may effect diff tracking.

  use ExUnit.Case, async: true

  import Phoenix.Component

  alias Phoenix.LiveView.{Socket, Diff}

  defp wrapper(assigns) do
    ~H[*** <%= render_slot(@inner_block, "ARG") %> ***]
  end

  def inner(assigns) do
    ~H[<%= @label %>: <%= @content %>]
  end

  test "component not using slot args won't be resent when unrelated/unused assigns change" do
    assigns = %{socket: %Socket{}, some_assign: "SOME_ASSIGN", other_assign: "OTHER_ASSIGN"}

    comp = fn assigns ->
      ~H"""
      <.wrapper :let={_arg}>
        <%= @some_assign %>
        <.inner label="INNER WITH ARG" content={@other_assign}/>
      </.wrapper>
      """
    end

    {socket, full_render, components} = render(comp.(assigns))

    assert has_dynamic_part?(full_render, "INNER WITH ARG")

    assigns = Map.put(assigns, :__changed__, %{some_assign: true})

    {_, full_render, _} = render(comp.(assigns), socket.fingerprints, components)

    assert has_dynamic_part?(full_render, "SOME_ASSIGN")
    refute has_dynamic_part?(full_render, "INNER WITH ARG")
  end

  test "component using slot args won't be resent when unrelated/unused assigns change outside the parent" do
    assigns = %{socket: %Socket{}, some_assign: "SOME_ASSIGN"}

    comp = fn assigns ->
      ~H"""
      <%= @some_assign %>
      <.wrapper :let={arg}>
        <.inner label="INNER WITH ARG" content={arg}/>
      </.wrapper>
      """
    end

    {socket, full_render, components} = render(comp.(assigns))

    assert has_dynamic_part?(full_render, "INNER WITH ARG")

    assigns = Map.put(assigns, :__changed__, %{some_assign: true})

    {_, full_render, _} = render(comp.(assigns), socket.fingerprints, components)

    assert has_dynamic_part?(full_render, "SOME_ASSIGN")
    refute has_dynamic_part?(full_render, "INNER WITH ARG")
  end

  test "component using slot args are resent when unrelated but used assigns change in body" do
    assigns = %{socket: %Socket{}, some_assign: "SOME_ASSIGN", other_assign: "OTHER_ASSIGN"}

    comp = fn assigns ->
      ~H"""
      <.wrapper :let={arg}>
        <%= @some_assign %>
        <.inner label="INNER WITH ARG" content={arg}/>
      </.wrapper>
      """
    end

    {socket, full_render, components} = render(comp.(assigns))

    assert has_dynamic_part?(full_render, "INNER WITH ARG")

    assigns = Map.put(assigns, :__changed__, %{some_assign: true})

    {_, full_render, _} = render(comp.(assigns), socket.fingerprints, components)

    # TODO: Why "INNER WITH ARG" is resent? It shouldn't!
    assert has_dynamic_part?(full_render, "INNER WITH ARG")
  end

  test "component using slot args are resent when unrelated but used assigns change" do
    assigns = %{socket: %Socket{}, some_assign: "SOME_ASSIGN"}

    comp = fn assigns ->
      ~H"""
      <.wrapper :let={arg}>
        <.inner label="INNER WITH AS SIGN" content={@some_assign}/>
        <.inner label="INNER WITH ARG" content={arg}/>
      </.wrapper>
      """
    end

    {socket, full_render, components} = render(comp.(assigns))

    assert has_dynamic_part?(full_render, "INNER WITH ARG")

    assigns = Map.put(assigns, :__changed__, %{some_assign: true})

    {_, full_render, _} = render(comp.(assigns), socket.fingerprints, components)

    # TODO: Why "INNER WITH ARG" is resent? It shouldn't!
    assert has_dynamic_part?(full_render, "INNER WITH ARG")
  end

  test "static surface props are not resent after first rendering" do
    import Surface

    assigns = %{socket: %Socket{}, content: "DYN CONTENT"}

    comp = fn assigns ->
      ~F"""
      <.inner label="STATIC LABEL" content={@content} {...dyn: 1}/>
      """
    end

    {socket, full_render, components} = render(comp.(assigns))

    assert has_dynamic_part?(full_render, "STATIC LABEL")

    assigns = Map.put(assigns, :__changed__, %{content: true})

    {_, full_render, _} = render(comp.(assigns), socket.fingerprints, components)

    assert has_dynamic_part?(full_render, "DYN CONTENT")
    refute has_dynamic_part?(full_render, "STATIC LABEL")
  end

  test "phx-* attributes with string values are static so they're not resent after first rendering" do
    import Surface

    assigns = %{socket: %Socket{}, content: "DYN CONTENT"}

    comp = fn assigns ->
      ~F"""
      <button phx-click="click">{@content}</button>
      """
    end

    {socket, full_render, components} = render(comp.(assigns))

    assert full_render[:s] == ["<button phx-click=\"click\">", "</button>\n"]

    assigns = Map.put(assigns, :__changed__, %{content: true})

    {_, full_render, _} = render(comp.(assigns), socket.fingerprints, components)

    assert full_render == %{0 => "DYN CONTENT"}
  end

  # TODO: optimize :on-* with literal values
  # test ":on-* attributes with string values are static so they're not resent after first rendering" do
  #   import Surface

  #   assigns = %{socket: %Socket{}, content: "DYN CONTENT"}

  #   comp = fn assigns ->
  #     ~F"""
  #     <button :on-click="click">{@content}</button>
  #     """
  #   end

  #   {socket, full_render, components} = render(comp.(assigns))

  #   assert full_render[:s] == ["<button phx-click=\"click\">", "</button>\n"]

  #   assigns = Map.put(assigns, :__changed__, %{content: true})

  #   {_, full_render, _} = render(comp.(assigns), socket.fingerprints, components)

  #   assert full_render == %{0 => "DYN CONTENT"}
  # end

  defp render(
         rendered,
         fingerprints \\ Diff.new_fingerprints(),
         components \\ Diff.new_components()
       ) do
    socket = %Socket{endpoint: __MODULE__, fingerprints: fingerprints}
    Diff.render(socket, rendered, components)
  end

  defp has_dynamic_part?([{_, value} | _rest], value) do
    true
  end

  defp has_dynamic_part?([{_, node} | rest], value) do
    has_dynamic_part?(node, value) or has_dynamic_part?(rest, value)
  end

  defp has_dynamic_part?([value | _rest], value) do
    true
  end

  defp has_dynamic_part?([_node | rest], value) do
    has_dynamic_part?(rest, value)
  end

  defp has_dynamic_part?(%{} = node, value) do
    node |> Map.to_list() |> has_dynamic_part?(value)
  end

  defp has_dynamic_part?(_node, _value) do
    false
  end
end
