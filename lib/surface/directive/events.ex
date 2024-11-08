defmodule Surface.Directive.Events do
  use Surface.Directive

  @events_by_group [
    click: [
      "click",
      "click-away",
      # TODO: Remove this when LV min is >= v0.20.15
      "capture-click"
    ],
    form: [
      "change",
      "submit"
    ],
    focus: [
      "blur",
      "focus",
      "window-blur",
      "window-focus"
    ],
    key: [
      "keydown",
      "keyup",
      "window-keydown",
      "window-keyup"
    ],
    scroll: [
      "viewport-top",
      "viewport-bottom"
    ]
  ]

  @events Enum.flat_map(@events_by_group, fn {_k, v} -> v end)

  @phx_events Enum.map(@events, &"phx-#{&1}")

  @doc false
  def events_by_group(), do: @events_by_group

  @doc false
  def names(), do: @events

  def phx_events(), do: @phx_events

  def extract({":on-" <> event_name, value, attr_meta}, meta)
      when event_name in @events do
    name = String.to_atom(event_name)

    %AST.Directive{
      module: __MODULE__,
      name: name,
      value: to_quoted_expr(name, value, meta),
      meta: Helpers.to_meta(attr_meta, meta)
    }
  end

  def extract(_, _), do: []

  def process(
        %AST.Directive{
          name: event_name,
          value: %AST.AttributeExpr{value: value} = expr,
          meta: meta
        },
        %type{attributes: attributes} = node
      )
      when type in [AST.Tag, AST.VoidTag] do
    value =
      quote do
        [{unquote("phx-#{event_name}"), {:event, unquote(value)}}]
      end

    %{
      node
      | attributes: [
          %AST.DynamicAttribute{name: event_name, meta: meta, expr: %{expr | value: value}}
          | attributes
        ]
    }
  end

  defp to_quoted_expr(_name, [], meta) do
    AST.AttributeExpr.new(nil, "", meta)
  end

  defp to_quoted_expr(name, value, meta) when is_list(value) do
    to_quoted_expr(name, to_string(value), meta)
  end

  defp to_quoted_expr(name, event, meta) when is_binary(event) or is_bitstring(event) do
    quoted = Surface.TypeHandler.expr_to_quoted!(Macro.to_string(event), name, :event, meta)
    AST.AttributeExpr.new(quoted, event, meta)
  end

  defp to_quoted_expr(name, {:attribute_expr, original, expr_meta}, meta) do
    expr_meta = Helpers.to_meta(expr_meta, meta)
    quoted = Surface.TypeHandler.expr_to_quoted!(original, name, :event, expr_meta)
    expr = AST.AttributeExpr.new(quoted, original, expr_meta)

    # We force the value to be evaluated at runtime
    %Surface.AST.AttributeExpr{expr | constant?: false}
  end
end
