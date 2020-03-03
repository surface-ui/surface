defmodule Surface.ContentHandler do
  @moduledoc false

  import Phoenix.LiveView.Helpers, only: [sigil_L: 2]

  defmacro __before_compile__(_env) do
    quote do
      defoverridable render: 1

      def render(assigns) do
        assigns = unquote(__MODULE__).init_contents(assigns)
        super(assigns)
      end
    end
  end

  def init_contents(assigns) do
    {%{__default__: default_slot}, other_slots} =
      assigns
      |> get_in([:__surface__, :slots])
      |> Map.split([:__default__])

    props =
      for {name, %{size: _size, binding: binding}} <- other_slots, into: %{} do
        value =
          assigns[name]
          |> Enum.with_index()
          |> Enum.map(fn {assign, index} ->
            Map.put(assign, :inner_content, data_content_fun(assigns, name, index, binding: binding))
          end)
        {name, value}
      end

    content = default_content_fun(assigns, default_slot.size, binding: default_slot.binding)

    assigns
    |> Map.merge(props)
    |> Map.put(:inner_content, content)
  end

  defp data_content_fun(assigns, name, index, binding: true) do
    fn args -> assigns.inner_content.({name, index, args_to_map(args)}) end
  end

  defp data_content_fun(assigns, name, index, binding: false) do
    fn -> assigns.inner_content.({name, index, %{}}) end
  end

  defp default_content_fun(assigns, size, binding: true) do
    fn args -> join_contents(assigns, size, args_to_map(args)) end
  end

  defp default_content_fun(assigns, size, binding: false) do
    fn -> join_contents(assigns, size, %{}) end
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
