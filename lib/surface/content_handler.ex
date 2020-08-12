defmodule Surface.ContentHandler do
  @moduledoc false

  import Phoenix.LiveView.Helpers, only: [sigil_L: 2]

  defmacro __before_compile__(env) do
    if Module.defines?(env.module, {:render, 1}) do
      quote do
        defoverridable render: 1

        def render(assigns) do
          assigns = unquote(__MODULE__).init_contents(assigns, __MODULE__)
          super(assigns)
        end
      end
    end
  end

  def init_contents(assigns, module) do
    {%{__default__: default_slot}, _other_slots} =
      case assigns[:__surface__][:slots] do
        nil ->
          {%{__default__: %{size: 0}}, []}

        slots ->
          Map.split(slots, [:__default__])
      end

    declared_slots = Enum.map(module.__slots__(), fn slot -> slot.name end)

    props =
      for name <- declared_slots, name != :default, into: %{} do
        value =
          if assigns[name] do
            assigns[name]
            |> Enum.with_index()
            |> Enum.map(fn {assign, index} ->
              Map.put(
                assign,
                :inner_content,
                data_content_fun(assigns, name, index)
              )
            end)
          end

        {name, value}
      end

    content = default_content_fun(assigns, default_slot.size)

    assigns =
      if default_slot.size > 0 do
        Map.put(assigns, :inner_content, content)
      else
        Map.put(assigns, :inner_content, nil)
      end

    Map.merge(assigns, props)
  end

  defp data_content_fun(assigns, name, index) do
    fn
      {args, ctx_assigns} ->
        assigns.inner_content({name, index, {args_to_map(args), ctx_assigns}})

      args ->
        assigns.inner_content.({name, index, {args_to_map(args), assigns}})
    end
  end

  defp default_content_fun(assigns, size) do
    fn
      {args, ctx_assigns} -> join_contents(assigns, size, args_to_map(args), ctx_assigns)
      args -> join_contents(assigns, size, args_to_map(args), assigns)
    end
  end

  defp join_contents(assigns, size, args, assigns_to_pass) do
    ~L"""
    <%= if assigns[:inner_content] != nil do %>
    <%= for index <- 0..size-1 do %><%= assigns.inner_content.({:__default__, index, {args, assigns_to_pass}}) %><% end %>
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
