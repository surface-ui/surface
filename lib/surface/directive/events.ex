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

  def extract({":on-" <> event_name, value, attr_meta}, meta)
      when event_name in @phx_events do
    name = String.to_atom(event_name)

    %AST.Directive{
      module: __MODULE__,
      name: name,
      value: to_quoted_expr(value, meta),
      meta: Helpers.to_meta(attr_meta, meta)
    }
  end

  def extract(_, _), do: []

  def process(
        %AST.Directive{name: name, value: %AST.Text{} = value, meta: meta},
        %type{attributes: attributes} = node
      )
      when type in [AST.Tag, AST.VoidTag] do
    attributes = [
      %AST.Attribute{
        name: name,
        type: :string,
        value: [value],
        meta: meta
      }
      | attributes
    ]

    %{node | attributes: attributes}
  end

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
          %{name: name, target: target} -> {name, target}
          [name | opts] when is_binary(name) -> {name, Keyword.get(opts, :target)}
          opts when is_list(opts) -> {Keyword.get(opts, :name), Keyword.get(opts, :target)}
          name when is_binary(name) -> {name, nil}
          nil -> nil
          _ -> raise "failed to parse event"
        end
        |> case do
          nil ->
            []

          {nil, _} ->
            raise "events require a name"

          {name, nil} ->
            [{unquote(event_name), {:string, name}}]

          {name, target} ->
            [{unquote(event_name), {:string, name}}, "phx-target": {:string, target}]
        end
      end

    %{node | attributes: [%AST.DynamicAttribute{expr: %{expr | value: value}} | attributes]}
  end

  defp to_quoted_expr({:attribute_expr, [original], expr_meta}, meta) do
    expr_meta = Helpers.to_meta(expr_meta, meta)

    value =
      original
      |> Helpers.attribute_expr_to_quoted!(:map, expr_meta)
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

  defp to_quoted_expr(value, _meta) when is_binary(value) or is_bitstring(value) do
    %AST.Text{value: value}
  end

  defp to_quoted_expr(value, _meta) when is_list(value) do
    %AST.Text{value: to_string(value)}
  end
end
