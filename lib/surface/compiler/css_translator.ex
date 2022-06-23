defmodule Surface.Compiler.CSSTranslator do
  alias Surface.Compiler.CSSParser

  @closing_symbol %{
    "{" => "}",
    "(" => ")",
    "[" => "]"
  }

  def translate!(css, opts \\ []) do
    module = Keyword.get(opts, :module)
    scope_id = Keyword.get(opts, :scope_id) || scope_id(module)
    file = Keyword.get(opts, :file)
    line = Keyword.get(opts, :line) || 1

    state = %{
      scope_id: scope_id,
      file: file,
      line: line,
      vars: %{},
      selectors: %{
        elements: MapSet.new(),
        classes: MapSet.new(),
        ids: MapSet.new(),
        other: MapSet.new()
      }
    }

    {updated_tokens, state} =
      css
      |> CSSParser.parse!(opts)
      |> translate([], state)

    %{
      scope_id: scope_id,
      file: file,
      css: to_string(updated_tokens),
      selectors: state.selectors,
      vars: state.vars
    }
  end

  defp translate([{:text, "s-bind"}, {:block, "(", arg, meta} | rest], acc, state) do
    expr = s_bind_arg_to_string(arg)
    name = var_name(state.scope_id, expr)
    vars = Map.put(state.vars, name, {expr, meta})
    translate(rest, ["var(#{name})" | acc], %{state | vars: vars})
  end

  defp translate([:semicolon | rest], acc, state) do
    translate(rest, [";" | acc], state)
  end

  defp translate([:comma | rest], acc, state) do
    translate(rest, ["," | acc], state)
  end

  defp translate([{:ws, ws} | rest], acc, state) do
    translate(rest, [ws | acc], state)
  end

  defp translate([{:text, text} | rest], acc, state) do
    translate(rest, [text | acc], state)
  end

  defp translate([{:string, delimiter, text} | rest], acc, state) do
    translate(rest, [delimiter, text, delimiter | acc], state)
  end

  defp translate([{:comment, text} | rest], acc, state) do
    translate(rest, ["*/", text, "/*" | acc], state)
  end

  defp translate([{:at_rule, tokens} | rest], acc, state) do
    {updated_tokens, state} = translate(tokens, [], state)
    acc = [updated_tokens | acc]
    translate(rest, acc, state)
  end

  defp translate([{:selector, tokens} | rest], acc, state) do
    {updated_tokens, state} = translate_selector(tokens, [], state)
    acc = [updated_tokens | acc]
    translate(rest, acc, state)
  end

  defp translate([{:declaration, tokens} | rest], acc, state) do
    {updated_tokens, state} = translate(tokens, [], state)
    acc = [updated_tokens | acc]
    translate(rest, acc, state)
  end

  defp translate([{:block, symbol, tokens, _meta} | rest], acc, state) do
    {updated_tokens, state} = translate(tokens, [], state)
    acc = [@closing_symbol[symbol], updated_tokens, symbol | acc]
    translate(rest, acc, state)
  end

  defp translate([], acc, state) do
    {Enum.reverse(acc), state}
  end

  defp translate_selector([{:text, ":deep"}, {:block, "(", arg, _meta} | rest], acc, state) do
    {updated_tokens, state} = translate(arg, [], state)
    acc = [updated_tokens | acc]
    translate_selector(rest, acc, state)
  end

  defp translate_selector([{:text, text} | rest], acc, state) do
    # TODO: replace this with a more accurate regex for each case (class, id, element, etc.)
    regex = ~r/^([a-zA-Z\d\*\.\#\&\-\_]+)(.*)$/

    sel =
      case Regex.run(regex, text) do
        [_, sel, _] -> sel
        _ -> nil
      end

    %{elements: elements, classes: classes, ids: ids, other: other} = state.selectors

    selectors =
      case sel do
        nil -> state.selectors
        "." <> class -> %{state.selectors | classes: MapSet.put(classes, class)}
        "#" <> id -> %{state.selectors | ids: MapSet.put(ids, id)}
        <<first, _::binary>> when first in ?a..?z -> %{state.selectors | elements: MapSet.put(elements, sel)}
        _ -> %{state.selectors | other: MapSet.put(other, sel)}
      end

    updated_text = Regex.replace(regex, text, "\\1[data-s-#{state.scope_id}]\\2", global: false)
    acc = [updated_text | acc]

    translate_selector(rest, acc, %{state | selectors: selectors})
  end

  defp translate_selector([token | rest], acc, state) do
    {updated_tokens, state} = translate([token], [], state)
    translate_selector(rest, [updated_tokens | acc], state)
  end

  defp translate_selector([], acc, state) do
    {Enum.reverse(acc), state}
  end

  defp s_bind_arg_to_string(tokens) do
    # TODO: validate invalid value
    [expr] =
      Enum.reduce(tokens, [], fn
        {:string, _, text}, acc -> [text | acc]
        {:ws, _}, acc -> acc
      end)

    expr
  end

  defp var_name(scope, expr) do
    hash = hash(scope <> expr)
    # TODO: In prod, use only the hash
    "--#{hash}-#{Regex.replace(~r/([^\w-])/, expr, "-")}"
  end

  defp scope_id(component) do
    component
    |> inspect()
    |> hash()
  end

  defp hash(text) do
    :crypto.hash(:md5, text)
    |> Base.encode16(case: :lower)
    |> String.slice(0..6)
  end
end
