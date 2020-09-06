defmodule Surface.Directive.ContextSet do
  use Surface.Directive

  def extract({":set", {:attribute_expr, value, expr_meta}, attr_meta}, meta) do
    expr_meta = Helpers.to_meta(expr_meta, meta)
    attr_meta = Helpers.to_meta(attr_meta, meta)

    %AST.Directive{
      module: __MODULE__,
      name: :set,
      value: directive_value(value, expr_meta),
      meta: attr_meta
    }
  end

  def extract(_, _), do: []

  def process(
        %AST.Directive{value: value, meta: directive_meta},
        %AST.Component{module: Surface.Components.Context, props: props, meta: node_meta} = node
      ) do
    set_prop = %AST.Attribute{
      type: :context_set,
      type_opts: [accumulate: true],
      name: :__set__,
      value: value,
      meta: directive_meta
    }

    {default_content_prop, props} =
      extract_or_create_prop(
        props,
        :__default_content__,
        :fun,
        %AST.AttributeExpr{
          original: " @inner_content ",
          value:
            quote do
              @inner_content
            end,
          meta: node_meta
        },
        node_meta
      )

    {slot_content_prop, props} =
      extract_or_create_prop(
        props,
        :__slot_content__,
        :keyword,
        slot_content_prop_value(node_meta),
        node_meta
      )

    props = [set_prop | [default_content_prop | [slot_content_prop | props]]]

    %{
      node
      | props: props
    }
  end

  defp directive_value(value, meta) do
    expr = Surface.TypeHandler.expr_to_quoted!(value, ":set", :context_set, meta)

    %AST.AttributeExpr{
      value: expr,
      original: value,
      meta: meta
    }
  end

  defp slot_content_prop_value(%{caller: caller} = meta) do
    value =
      caller
      |> Surface.API.get_slots()
      |> Enum.reject(fn %{name: name} -> name == :default end)
      |> Enum.map(fn %{name: name} -> {name, at_ref(name)} end)

    %AST.AttributeExpr{
      original: Macro.to_string(value),
      value: value,
      meta: meta
    }
  end

  defp at_ref(name) do
    {:@, [generated: true], [{name, [generated: true], nil}]}
  end

  defp extract_or_create_prop(props, attr_name, attr_type, default, meta) do
    props
    |> Enum.split_with(fn
      %{name: name} when name == attr_name -> true
      _ -> false
    end)
    |> case do
      {[prop], not_prop} ->
        {prop, not_prop}

      {_, not_prop} ->
        {%AST.Attribute{
           name: attr_name,
           type: attr_type,
           value: default,
           meta: meta
         }, not_prop}
    end
  end
end
