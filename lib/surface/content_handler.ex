defmodule Surface.ContentHandler do
  @moduledoc false

  import Phoenix.LiveView.Helpers, only: [sigil_L: 2]

  defmacro __before_compile__(env) do
    if Module.defines?(env.module, {:render, 1}) do
      quote do
        defoverridable render: 1

        def render(assigns) do
          assigns = unquote(__MODULE__).init_contents(assigns)
          super(assigns)
        end
      end
    end
  end

  def init_contents(assigns) do
    {%{__default__: default_slot}, other_slots} =
      assigns
      |> get_in([:__surface__, :slots])
      |> Map.split([:__default__])

    props =
      for {name, %{size: _size}} <- other_slots, into: %{} do
        value =
          assigns[name]
          |> Enum.with_index()
          |> Enum.map(fn {assign, index} ->
            Map.put(
              assign,
              :inner_content,
              data_content_fun(assigns, name, index)
            )
          end)

        {name, value}
      end

    content = default_content_fun(assigns, default_slot.size)

    assigns =
      if default_slot.size > 0 do
        Map.put(assigns, :inner_content, content)
      else
        Map.delete(assigns, :inner_content)
      end

    Map.merge(assigns, props)
  end

  defp data_content_fun(assigns, name, index) do
    fn args -> assigns.inner_content.({name, index, args_to_map(args)}) end
  end

  defp default_content_fun(assigns, size) do
    fn args -> join_contents(assigns, size, args_to_map(args)) end
  end

  defp join_contents(assigns, size, args) do
    ~L"""
    <%= if assigns[:inner_content] != nil do %>
    <%= for index <- 0..size-1 do %><%= assigns.inner_content.({:__default__, index, args}) %><% end %>
    <% end %>
    """
  end

  defp args_to_map(args) do
    if Keyword.keyword?(args) do
      Map.new(args)
    else
      stacktrace =
        self()
        |> Process.info(:current_stacktrace)
        |> elem(1)
        |> Enum.drop(3)

      message = "invalid slot props. Expected a keyword list, got: #{inspect(args)}"
      reraise(message, stacktrace)
    end
  end
end
