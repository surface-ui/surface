defmodule Surface.TypeHandler.CssClass do
  @moduledoc false

  use Surface.TypeHandler

  @impl true
  def literal_to_ast_node(_type, _name, "", _meta) do
    {:ok, %Surface.AST.Literal{value: ""}}
  end

  def literal_to_ast_node(type, name, value, meta) do
    {:ok,
     %Surface.AST.AttributeExpr{
       original: value,
       value: Surface.TypeHandler.expr_to_quoted!(Macro.to_string(value), name, type, meta),
       meta: meta
     }}
  end

  @impl true
  def expr_to_value([value], opts) when is_list(value) do
    expr_to_value(value, opts)
  end

  def expr_to_value(clauses, opts) do
    value =
      Enum.reduce(clauses ++ opts, [], fn item, classes ->
        case item do
          list when is_list(list) ->
            case expr_to_value(list, []) do
              {:ok, new_classes} -> Enum.reverse(new_classes) ++ classes
              error -> error
            end

          {class, val} when val not in [nil, false] ->
            maybe_add_class(classes, class)

          class when is_binary(class) or is_atom(class) ->
            maybe_add_class(classes, class)

          _ ->
            classes
        end
      end)
      |> Enum.reverse()

    {:ok, value}
  end

  @impl true
  def value_to_html(_name, value) do
    {:ok, Enum.join(value, " ")}
  end

  @impl true
  def value_to_opts(_name, value) do
    {:ok, Enum.join(value, " ")}
  end

  defp maybe_add_class(classes, class) do
    new_classes =
      class
      |> to_string()
      |> String.split(" ", trim: true)
      |> Enum.reverse()

    new_classes ++ classes
  end
end
