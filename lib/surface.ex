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

  @doc false
  def attr_value(attr, value) do
    if String.Chars.impl_for(value) do
      value
    else
      IOHelper.runtime_error(
        "invalid value for attribute \"#{attr}\". Expected a type that implements " <>
          "the String.Chars protocol (e.g. string, boolean, integer, atom, ...), " <>
          "got: #{inspect(value)}"
      )
    end
  end

  @doc false
  def build_assigns(context, props, slot_props, slots, module) do
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

    context = Keyword.put(context, module, module_ctx)

    Map.new(
      props ++
        slot_props ++
        sets_in_scope_from_context ++
        [
          __surface__: %{
            context: context,
            slots: Map.new(slots),
            provided_templates: Keyword.keys(slot_props)
          }
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
  def css_class([value]) when is_list(value) do
    css_class(value)
  end

  def css_class(value) when is_binary(value) do
    value
  end

  def css_class(value) when is_list(value) do
    Enum.reduce(value, [], fn item, classes ->
      case item do
        {class, val} when val not in [nil, false] ->
          maybe_add_class(classes, class)

        class when is_binary(class) or is_atom(class) ->
          maybe_add_class(classes, class)

        _ ->
          classes
      end
    end)
    |> Enum.reverse()
    |> Enum.join(" ")
  end

  def css_class(value) do
    IOHelper.runtime_error(
      "invalid value for property of type :css_class. " <>
        "Expected a string or a keyword list, got: #{inspect(value)}"
    )
  end

  @doc false
  def boolean_attr(name, value) do
    if value do
      name
    else
      ""
    end
  end

  @doc false
  def keyword_value(key, value) do
    if Keyword.keyword?(value) do
      value
    else
      IOHelper.runtime_error(
        "invalid value for property \"#{key}\". Expected a :keyword, got: #{inspect(value)}"
      )
    end
  end

  @doc false
  def map_value(_key, value) when is_map(value) do
    value
  end

  def map_value(key, value) do
    if Keyword.keyword?(value) do
      Map.new(value)
    else
      IOHelper.runtime_error(
        "invalid value for property \"#{key}\". Expected a :map, got: #{inspect(value)}"
      )
    end
  end

  @doc false
  def event_value(key, [event], caller_cid) do
    event_value(key, event, caller_cid)
  end

  def event_value(key, [name | opts], caller_cid) do
    event = Map.new(opts) |> Map.put(:name, name)
    event_value(key, event, caller_cid)
  end

  def event_value(_key, nil, _caller_cid) do
    nil
  end

  def event_value(_key, name, nil) when is_binary(name) do
    %{name: name, target: :live_view}
  end

  def event_value(_key, name, caller_cid) when is_binary(name) do
    %{name: name, target: to_string(caller_cid)}
  end

  def event_value(_key, %{name: _, target: _} = event, _caller_cid) do
    event
  end

  def event_value(key, event, _caller_cid) do
    IOHelper.runtime_error(
      "invalid value for event \"#{key}\". Expected an :event or :string, got: #{inspect(event)}"
    )
  end

  @doc false
  def phx_event(_phx_event, value) when is_binary(value) do
    value
  end

  def phx_event(phx_event, value) do
    IOHelper.runtime_error(
      "invalid value for \"#{phx_event}\". LiveView bindings only accept values " <>
        "of type :string. If you want to pass an :event, please use directive " <>
        ":on-#{phx_event} instead. Expected a :string, got: #{inspect(value)}"
    )
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

  defp maybe_add_class(classes, class) do
    case class |> to_string() |> String.trim() do
      "" ->
        classes

      class ->
        [class | classes]
    end
  end

  defp get_components_config() do
    Application.get_env(:surface, :components, [])
  end
end
