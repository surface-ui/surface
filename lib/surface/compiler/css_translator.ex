defmodule Surface.Compiler.CSSTranslator do
  @moduledoc false
  alias Surface.Compiler.CSSParser

  @closing_symbol %{
    "{" => "}",
    "(" => ")",
    "[" => "]"
  }

  def translate!(css, opts \\ []) do
    module = Keyword.get(opts, :module)
    func = Keyword.get(opts, :func)
    scope_id = Keyword.get(opts, :scope_id) || scope_id(module, func)
    file = Keyword.get(opts, :file)
    line = Keyword.get(opts, :line) || 1
    env = Keyword.get(opts, :env) || :dev

    state = %{
      scope_id: scope_id,
      file: file,
      line: line,
      env: env,
      vars: %{},
      selectors_buffer: [],
      selectors: %{
        elements: MapSet.new(),
        classes: MapSet.new(),
        ids: MapSet.new(),
        combined: MapSet.new(),
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
      line: line,
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

  defp translate([{:comma, _} | rest], acc, state) do
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

  defp translate_selector([{:ws, ws} | rest], acc, state) do
    state = end_selector(state)
    translate_selector(rest, [ws | acc], state)
  end

  defp translate_selector([{:text, combinator} | rest], acc, state)
       when combinator in [">", "~", "+"] do
    state = end_selector(state)
    translate_selector(rest, [combinator | acc], state)
  end

  defp translate_selector([{:text, ":deep"}, {:block, "(", arg, _meta} | rest], acc, state) do
    {updated_tokens, state} = translate(arg, [], state)
    acc = [updated_tokens | acc]
    translate_selector(rest, acc, state)
  end

  defp translate_selector([{:text, text} | rest], acc, state) do
    {scoped?, state} =
      case text do
        "." <> class ->
          state = %{state | selectors_buffer: [{:classes, "." <> class, class} | state.selectors_buffer]}
          {true, state}

        "#" <> id ->
          state = %{state | selectors_buffer: [{:ids, "#" <> id, id} | state.selectors_buffer]}
          {true, state}

        <<first, _::binary>> when first in ?a..?z ->
          state = %{state | selectors_buffer: [{:elements, text, text} | state.selectors_buffer]}
          {true, state}

        c when c in ["*", "&"] ->
          state = %{state | selectors_buffer: [{:other, c, c} | state.selectors_buffer]}
          {true, state}

        _ ->
          {false, state}
      end

    acc =
      if scoped? do
        ["#{text}[data-s-#{state.scope_id}]" | acc]
      else
        [text | acc]
      end

    translate_selector(rest, acc, state)
  end

  defp translate_selector([token | rest], acc, state) do
    {updated_tokens, state} = translate([token], [], state)
    translate_selector(rest, [updated_tokens | acc], state)
  end

  defp translate_selector([], acc, state) do
    state = end_selector(state)
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
    "--#{hash(scope <> expr)}"
  end

  defp scope_id(component, func) do
    hash("#{inspect(component)}.#{func}")
  end

  defp hash(text) do
    :crypto.hash(:md5, text)
    |> Base.encode16(case: :lower)
    |> String.slice(0..6)
  end

  defp put_selector(state, group, selector) do
    update_in(state, [:selectors, group], fn sels ->
      MapSet.put(sels, selector)
    end)
  end

  defp end_selector(%{selectors_buffer: selectors_buffer} = state) do
    state =
      case selectors_buffer do
        [] ->
          state

        [{group, _text, sel}] ->
          put_selector(state, group, sel)

        list ->
          combined = MapSet.new(list, fn {_group, text, _sel} -> text end)
          put_selector(state, :combined, combined)
      end

    %{state | selectors_buffer: []}
  end
end
