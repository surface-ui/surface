defmodule Surface.Construct do
  alias Surface.AST

  @callback process(directive :: Surface.AST.Directive.t(), node :: Surface.AST.t()) ::
              Surface.AST.t()

  defmacro __using__(opts) do
    name = Keyword.fetch!(opts, :name)
    pattern = Keyword.get(opts, :pattern, to_string(name))
    type = Keyword.get(opts, :type, :any)
    modifiers = Keyword.get(opts, :modifiers, [])

    create_directive = Keyword.get(opts, :directive)

    create_component = Keyword.has_key?(opts, :component)
    prop = opts[:component][:prop]

    quote do
      alias Surface.AST

      @behaviour unquote(__MODULE__)

      if unquote(create_directive) do
        defmodule Directive do
          use Surface.Directive,
            name: unquote(name),
            pattern: unquote(pattern),
            type: unquote(type),
            modifiers: unquote(modifiers)

          def process(directive, node) do
            unquote(__CALLER__.module).process(directive, node)
          end
        end
      end

      if unquote(create_component) do
        unquote(
          define_component_module(__CALLER__.module, name, type, prop[:name], prop[:default])
        )
      end
    end
  end

  defp define_component_module(module, construct_name, type, prop, default_prop_value) do
    {prop_name, _, _} = prop

    quote do
      defmodule Component do
        alias Surface.AST

        use Surface.Component

        prop unquote(prop), unquote(type), required: true
        slot default, required: true

        @dialyzer {:nowarn_function, render: 1}
        def render(_), do: ""

        def transform(node) do
          prop =
            unquote(__MODULE__).find_prop_value(
              node,
              unquote(prop_name),
              unquote(default_prop_value)
            )

          children = unquote(__MODULE__).node_children(node)

          unquote(__MODULE__).process_construct(
            unquote(module),
            unquote(construct_name),
            node,
            prop,
            children
          )
        end
      end
    end
  end

  def process_construct(module, construct_name, node, prop, children) do
    container = %AST.Container{
      directives: [],
      children: children,
      meta: node.meta
    }

    directive = %AST.Directive{
      module: module,
      name: construct_name,
      value: prop,
      meta: node.meta
    }

    module.process(directive, container)
  end

  def find_prop_value(node, name, default) do
    Enum.find_value(
      node.props,
      %AST.AttributeExpr{value: default, original: "", meta: node.meta},
      fn prop ->
        if prop.name == name do
          prop.value
        end
      end
    )
  end

  # TODO: how to prevent renderless components?
  def node_children(node) do
    if Enum.empty?(node.templates.default),
      do: [],
      else: List.first(node.templates.default).children
  end
end
