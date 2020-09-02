defmodule Surface do
  @moduledoc """
  Surface is component based library for **Phoenix LiveView**.

  Built on top of the new `Phoenix.LiveComponent` API, Surface provides
  a more declarative way to express and use components in Phoenix.

  Full documentation and live examples can be found at [surface-demo.msaraiva.io](http://surface-demo.msaraiva.io)

  This module defines the `~H` sigil that should be used to translate Surface
  code into Phoenix templates.

  In order to have `~H` available for any Phoenix view, add the following import to your web
  file in `lib/my_app_web.ex`:

      # lib/my_app_web.ex

      ...

      def view do
        quote do
          ...
          import Surface
        end
      end

  Additionally, use `Surface.init/1` in your mount function to initialize assigns used internally by surface:

      # A LiveView using surface templates

      defmodule PageLive do
        use Phoenix.LiveView
        import Surface

        def mount(socket) do
          socket = Surface.init(socket)
          ...
          {:ok, socket}
        end

        def render(assigns) do
          ~H"\""
          ...
          "\""
        end
      end

      # A LiveComponent using surface templates

      defmodule NavComponent do
        use Phoenix.LiveComponent
        import Surface

        def mount(socket) do
          socket = Surface.init(socket)
          ...
          {:ok, socket}
        end

        def render(assigns) do
          ~H"\""
          ...
          "\""
        end
      end

  ## Defining components

  To create a component you need to define a module and `use` one of the available component types:

    * `Surface.Component` - A stateless component.
    * `Surface.LiveComponent` - A live stateful component.
    * `Surface.LiveView` - A wrapper component around `Phoenix.LiveView`.
    * `Surface.MacroComponent` - A low-level component which is responsible for translating its own content at compile time.

  ### Example

      # A functional stateless component

      defmodule Button do
        use Surface.Component

        property click, :event
        property kind, :string, default: "is-info"

        def render(assigns) do
          ~H"\""
          <button class="button {{ @kind }}" phx-click={{ @click }}>
            <slot/>
          </button>
          "\""
        end
      end

  You can visit the documentation of each type of component for further explanation and examples.
  """

  alias Surface.IOHelper
  alias Phoenix.LiveView

  @doc """
  Translates Surface code into Phoenix templates.
  """
  defmacro sigil_H({:<<>>, _, [string]}, opts) do
    # This will create accurate line numbers for heredoc usages of the sigil, but
    # not for ~H* variants. See https://github.com/msaraiva/surface/issues/15#issuecomment-667305899
    line_offset = __CALLER__.line + 1

    string
    |> Surface.Compiler.compile(line_offset, __CALLER__, __CALLER__.file)
    |> Surface.Compiler.to_live_struct(
      debug: Enum.member?(opts, ?d),
      file: __CALLER__.file,
      line: __CALLER__.line
    )
  end

  @doc "Retrieve a component's config based on the `key`"
  defmacro get_config(component, key) do
    config = get_components_config()

    quote bind_quoted: [config: config, component: component, key: key] do
      config[component][key]
    end
  end

  @doc "Retrieve the component's config based on the `key`"
  defmacro get_config(key) do
    component = __CALLER__.module
    config = get_components_config()

    quote do
      unquote(config[component][key])
    end
  end

  @doc "Initialize surface state in the socket"
  def init(socket) do
    socket
    |> LiveView.assign_new(:__surface__, fn -> %{} end)
    |> LiveView.assign_new(:__context__, fn -> [] end)
    |> LiveView.assign_new(:__context2__, fn -> %{} end)
  end

  @doc false
  def default_props(module) do
    Enum.map(module.__props__(), fn %{name: name, opts: opts} -> {name, opts[:default]} end)
  end

  @doc false
  def build_assigns(
        context,
        context2,
        static_props,
        dynamic_props,
        slot_props,
        slots,
        module,
        node_alias
      ) do
    static_prop_names = Keyword.keys(static_props)

    dynamic_props =
      (dynamic_props || [])
      |> Enum.filter(fn {name, _} -> not Enum.member?(static_prop_names, name) end)
      |> Enum.map(fn {name, value} ->
        {name, Surface.TypeHandler.runtime_prop_value!(module, name, value, node_alias || module)}
      end)

    props = Keyword.merge(Keyword.merge(default_props(module), dynamic_props), static_props)

    gets_from_context =
      module
      |> context_gets()
      |> Enum.flat_map(fn {from, values} ->
        Enum.map(values, fn {name, as} ->
          ctx = Keyword.get(context, from, [])

          {as, Keyword.get(ctx, name)}
        end)
      end)

    props = Keyword.merge(gets_from_context, props)

    module_ctx = init_context(module, props)

    sets_in_scope_from_context =
      Enum.map(module.__context_sets_in_scope__(), fn %{name: name} ->
        {name, Keyword.get(module_ctx, name)}
      end)

    context =
      case module_ctx do
        [] -> context
        _ -> Keyword.put(context, module, module_ctx)
      end

    Map.new(
      props ++
        slot_props ++
        sets_in_scope_from_context ++
        [
          __surface__: %{
            slots: Map.new(slots),
            provided_templates: Keyword.keys(slot_props)
          },
          __context__: context,
          __context2__: context2
        ]
    )
  end

  defp context_gets(module) do
    module.__context_gets__()
    |> Enum.map(fn %{name: name, opts: opts} ->
      {opts[:from], {name, opts[:as] || name}}
    end)
    |> Enum.group_by(fn {from, _} -> from end, fn {_, opts} -> opts end)
    |> Keyword.new()
  end

  defp init_context(module, props) do
    with true <- function_exported?(module, :init_context, 1),
         {:ok, values} <- module.init_context(Map.new(props)) do
      values
    else
      false ->
        []

      {:error, message} ->
        IOHelper.runtime_error(message)

      result ->
        IOHelper.runtime_error(
          "unexpected return value from init_context/1. " <>
            "Expected {:ok, keyword()} | {:error, String.t()}, got: #{inspect(result)}"
        )
    end
  end

  @doc false
  def event_to_opts(%{name: name, target: :live_view}, event_name) do
    [{event_name, name}]
  end

  def event_to_opts(%{name: name, target: target}, event_name) do
    [{event_name, name}, {:phx_target, target}]
  end

  def event_to_opts(nil, _event_name) do
    []
  end

  defp get_components_config() do
    Application.get_env(:surface, :components, [])
  end
end
