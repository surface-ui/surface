defmodule Surface.Directive.Events do
  use Surface.Directive

  @phx_events [
    "phx-click",
    "phx-capture-click",
    "phx-blur",
    "phx-focus",
    "phx-change",
    "phx-submit",
    "phx-keydown",
    "phx-keyup",
    "phx-window-keydown",
    "phx-window-keyup"
  ]

  def phx_events(), do: @phx_events

  def extract({":on-" <> event_name, value, attr_meta}, meta)
      when event_name in @phx_events do
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
          value: %AST.AttributeExpr{value: value} = expr
        },
        %type{attributes: attributes} = node
      )
      when type in [AST.Tag, AST.VoidTag] do
    value =
      quote generated: true do
        case unquote(value) do
          %{name: name, target: :live_view} ->
            [{unquote(event_name), {:string, name}}]

          %{name: name, target: target} ->
            [{unquote(event_name), {:string, name}}, "phx-target": {:string, target}]

          nil ->
            []
        end
      end

    %{node | attributes: [%AST.DynamicAttribute{expr: %{expr | value: value}} | attributes]}
  end

  defp to_quoted_expr(name, value, meta) when is_list(value) do
    to_quoted_expr(name, to_string(value), meta)
  end

  defp to_quoted_expr(name, event, meta) when is_binary(event) or is_bitstring(event) do
    %AST.AttributeExpr{
      original: event,
      # using the helpers and quoting this because there is some logic around @myself vs. nil
      # that I don't want to duplicate
      value: Helpers.attribute_expr_to_quoted!(~s("#{event}"), name, :event, meta),
      meta: meta
    }
  end

  defp to_quoted_expr(name, {:attribute_expr, [original], expr_meta}, meta) do
    expr_meta = Helpers.to_meta(expr_meta, meta)

    value =
      original
      |> Helpers.attribute_expr_to_quoted!(name, :event, expr_meta)
      |> case do
        [name, opts] when is_binary(name) and is_list(opts) -> Keyword.put(opts, :name, name)
        [name | opts] when is_binary(name) and is_list(opts) -> Keyword.put(opts, :name, name)
        value -> value
      end

    %AST.AttributeExpr{
      original: original,
      value: value,
      meta: expr_meta
    }
  end
end
