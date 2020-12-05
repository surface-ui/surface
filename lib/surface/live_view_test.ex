defmodule Surface.LiveViewTest do
  @moduledoc """
  Conveniences for testing Surface components.
  """

  alias Surface.TypeHandler

  @doc """
  Helper function to test stateless components or regular rendering of a live component.

  The values passed in `assigns` must be in the runtime format. For instance, a property
  of type `:css_class` must be passed as list (e.g. `["btn", "active"]`). A property of
  type `:event` must be passed as `%{name: event_name, target: :live_view}`. This function
  accepts a block that will be used to fill in the default slot.

  ## Example

      html =
        render_surface_component(Link, to: "/users/1") do
          ~H"\""
          <span>user</span>
          "\""
        end

      assert html =~ "\""
            <a href="/users/1"><span>user</span></a>
            "\""

  ## Limitations

  Currently, this function cannot be used to test:

    * Slot props
    * Named slots
    * Contexts
    * Events on live components

  If your test depends on any of the features above, you need to use either
  `render_live/2` or `Phoenix.LiveViewTest.live_isolated/3`.

  """
  defmacro render_surface_component(component, assigns, opts \\ []) do
    block = Keyword.get(opts, :do)

    init_inner_block =
      if block do
        quote do
          var!(assigns) = %{}
          inner_block = unquote(block)
        end
      else
        quote do
          inner_block = nil
        end
      end

    quote do
      unquote(init_inner_block)

      render_component(
        unquote(component),
        unquote(__MODULE__).init_surface(unquote(component), inner_block, unquote(assigns)),
        unquote(opts)
      )
      |> unquote(__MODULE__).clean_html()
    end
  end

  @doc false
  def init_surface(component, inner_block, assigns \\ []) do
    props =
      component
      |> Surface.default_props()
      |> Keyword.merge(assigns)
      |> to_runtime_values(component)
      |> Surface.rename_id_if_stateless(component.component_type())
      |> Map.new()

    if inner_block do
      props
      |> Map.put(:inner_block, fn _, _ -> inner_block end)
      |> Map.put(:__surface__, %{provided_templates: [:__default__]})
    else
      props
      |> Map.put(:__surface__, %{provided_templates: []})
    end
  end

  @doc false
  def clean_html(html) do
    html
    |> String.replace(~r/\n+/, "\n")
    |> String.replace(~r/\n\s+\n/, "\n")
  end

  defp to_runtime_values(assigns, component) do
    Enum.map(assigns, fn {name, value} ->
      {name, TypeHandler.runtime_prop_value!(component, name, value, component)}
    end)
  end
end
