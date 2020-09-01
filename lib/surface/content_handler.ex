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
    {%{__default__: default_slot}, other_slots} =
      case assigns[:__surface__][:slots] do
        nil ->
          {%{__default__: %{size: 0, prop_assigns: []}}, []}

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
                data_content_fun(
                  assigns,
                  name,
                  index,
                  Enum.at(other_slots[name][:prop_assigns] || [], index, [])
                )
              )
            end)
          end

        {name, value}
      end

    content = default_content_fun(assigns, default_slot.size, default_slot.prop_assigns)

    assigns =
      if default_slot.size > 0 do
        Map.put(assigns, :inner_content, content)
      else
        Map.put(assigns, :inner_content, nil)
      end

    Map.merge(assigns, props)
  end

  defp data_content_fun(assigns, name, index, prop_assign_mappings) do
    fn args ->
      prop_assigns =
        Enum.map(prop_assign_mappings, fn {prop_name, assign_name} ->
          {assign_name, args[prop_name]}
        end)

      # TODO [Context]: Update this to be only the appropriate assigns for context
      surface_assign = args[:__surface__] || assigns.__surface__

      assigns.inner_content.(
        Keyword.merge(prop_assigns, __slot__: {name, index}, __surface__: surface_assign)
      )
    end
  end

  defp default_content_fun(assigns, size, all_prop_assign_mappings) do
    fn args ->
      # TODO [Context]: Update this to be only the appropriate assigns for context
      surface_assign = args[:__surface__] || assigns.__surface__

      prop_assigns =
        Enum.map(all_prop_assign_mappings, fn mappings_for_index ->
          Enum.map(mappings_for_index, fn {prop_name, assign_name} ->
            {assign_name, args[prop_name]}
          end)
        end)

      join_contents(assigns, size, surface_assign, prop_assigns)
    end
  end

  defp join_contents(assigns, size, surface_assign, assign_mappings) do
    ~L"""
    <%= if assigns[:inner_content] != nil do %>
    <%= for index <- 0..size-1 do %><%= assigns.inner_content.(Keyword.merge(Enum.at(assign_mappings, index), [__slot__: {:__default__, index}, __surface__: surface_assign])) %><% end %>
    <% end %>
    """
  end
end
