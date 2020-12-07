defmodule Surface.LiveViewTest do
  @moduledoc """
  Conveniences for testing Surface components.
  """

  alias Phoenix.LiveView.{Diff, Socket}

  defmodule BlockWrapper do
    @moduledoc false

    use Surface.Component

    slot default, required: true

    def render(assigns) do
      ~H"""
      <slot/>
      """
    end
  end

  @doc """
  Helper function to test the regular rendering of components.

  For tests depending on the existence of a parent live view, e.g. testing events on live
  components and its side-effects, you need to use either `render_live/2` or
  `Phoenix.LiveViewTest.live_isolated/3`.

  ## Example

      html =
        render_surface do
          ~H"\""
          <Link label="user" to="/users/1" />
          "\""
        end

      assert html =~ "\""
            <a href="/users/1">user</a>
            "\""

  """
  defmacro render_surface(do: do_block) do
    render_component_call =
      quote do
        Surface.LiveViewTest.render_component_with_block(
          Surface.LiveViewTest.BlockWrapper,
          %{__context__: %{}, __surface__: %{provided_templates: [:__default__]}},
          do: unquote(do_block)
        )
      end

    if Macro.Env.has_var?(__CALLER__, {:assigns, nil}) do
      quote do
        var!(assigns) = Map.merge(var!(assigns), %{__context__: %{}})
        unquote(render_component_call) |> Surface.LiveViewTest.clean_html()
      end
    else
      quote do
        var!(assigns) = %{__context__: %{}}
        unquote(render_component_call) |> Surface.LiveViewTest.clean_html()
      end
    end
  end

  # Custom version of phoenix's `render_component` that supports
  # passing a inner_block. This should be used until a compatible
  # version of phoenix_live_view is released.

  @doc false
  defmacro render_component_with_block(component, assigns, opts \\ [], do_block \\ []) do
    {do_block, opts} =
      case {do_block, opts} do
        {[do: do_block], _} -> {do_block, opts}
        {_, [do: do_block]} -> {do_block, []}
        {_, _} -> {nil, opts}
      end

    endpoint =
      Module.get_attribute(__CALLER__.module, :endpoint) ||
        raise ArgumentError,
              "the module attribute @endpoint is not set for #{inspect(__MODULE__)}"

    socket =
      quote do
        %Socket{endpoint: unquote(endpoint), router: unquote(opts)[:router]}
      end

    if do_block do
      quote do
        socket = unquote(socket)
        var!(assigns) = Map.put(var!(assigns), :socket, socket)

        inner_block = fn _, _args ->
          unquote(do_block)
        end

        assigns = unquote(assigns) |> Map.new() |> Map.put(:inner_block, inner_block)
        Surface.LiveViewTest.__render_component_with_block__(socket, unquote(component), assigns)
      end
    else
      quote do
        assigns = Map.new(unquote(assigns))

        Surface.LiveViewTest.__render_component_with_block__(
          unquote(socket),
          unquote(component),
          assigns
        )
      end
    end
  end

  @doc false
  def __render_component_with_block__(socket, component, assigns) do
    mount_assigns = if assigns[:id], do: %{myself: %Phoenix.LiveComponent.CID{cid: -1}}, else: %{}
    rendered = Diff.component_to_rendered(socket, component, assigns, mount_assigns)
    {_, diff, _} = Diff.render(socket, rendered, Diff.new_components())
    diff |> Diff.to_iodata() |> IO.iodata_to_binary()
  end

  @doc false
  def clean_html(html) do
    html
    |> String.replace(~r/\n+/, "\n")
    |> String.replace(~r/\n\s+\n/, "\n")
  end
end
