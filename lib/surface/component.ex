defmodule Surface.Component do
  @behaviour Surface.Translator.ComponentTranslator
  import Surface.Translator.ComponentTranslator

  alias Surface.Translator.{Directive, NodeTranslator}
  alias Surface.BaseComponent.{DataContent, LazyContent}

  defmacro __using__(_) do
    quote do
      use Surface.BaseComponent
      import Surface.Translator, only: [sigil_H: 2]

      import unquote(__MODULE__)
      @behaviour unquote(__MODULE__)

      def translator() do
        unquote(__MODULE__)
      end

      defoverridable translator: 0
    end
  end

  @callback begin_context(props :: map()) :: map()
  @callback end_context(props :: map()) :: map()
  @callback render(assigns :: map()) :: any
  @optional_callbacks begin_context: 1, end_context: 1

  def translate(mod, mod_str, attributes, directives, children, children_groups_contents, has_children?, caller) do
    # TODO:
    # Check if it's liveview, if so, use `live_component`, otherwise use own private renderer
    # - define `inner_content` and add it to the props

    translated_props = Surface.Properties.translate_attributes(attributes, mod, mod_str, caller)

    [
      Directive.maybe_add_directives_begin(directives),
      maybe_add_begin_context(mod, mod_str, translated_props),
      children_groups_contents,
      add_render_call("#{inspect(__MODULE__)}.render", [mod_str, translated_props], has_children?),
      Directive.maybe_add_directives_after_begin(directives),
      maybe_add(NodeTranslator.translate(children, caller), has_children?),
      maybe_add("<% end %>", has_children?),
      maybe_add_end_context(mod, mod_str, translated_props),
      Directive.maybe_add_directives_end(directives)
    ]
  end

  def render(module, props) do
    do_render(module, props, [])
  end

  def render(module, props, do: block) do
    do_render(module, props, block)
  end

  defp do_render(module, props, content) do
    props =
      props
      |> Map.put(:content, content)

    case module.render(props) do
      {:data, data} ->
        case data do
          %{content: {:safe, [%LazyContent{func: func}]}} ->
            %DataContent{data: Map.put(data, :inner_content, func), component: module}
          _ ->
            %DataContent{data: data, component: module}
        end
      result ->
        result
    end
  end
end
