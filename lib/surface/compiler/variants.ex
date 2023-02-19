defmodule Surface.Compiler.Variants do
  @moduledoc false

  @enum_types [:list, :keyword, :map, :mapset]
  @choice_types [:string, :atom, :integer]

  def generate(specs) do
    for spec <- Enum.reverse(specs), css_variant = spec.opts[:css_variant], reduce: {[], []} do
      {variants, data_variants} ->
        variant_opts = if css_variant == true, do: [], else: css_variant
        data_name = normalize_variant_name(spec.name)
        assign_ast = {:@, [], [{spec.name, [], nil}]}

        {type, all_variants, variants_specs} =
          case {spec.type, spec.opts[:values] || spec.opts[:values!]} do
            {:boolean, _} ->
              true_name = variant_opts[true] || data_name
              false_name = variant_opts[false] || "not-#{data_name}"

              {:boolean, [true_name, false_name | variants],
               [
                 {:data_present, true_name},
                 {:data_not_present, false_name}
               ]}

            {type, _} when type in @enum_types ->
              has_items_name = variant_opts[:has_items] || "has-#{data_name}"
              no_items_name = variant_opts[:no_items] || "no-#{data_name}"

              {:enum, [has_items_name, no_items_name | variants],
               [
                 {:data_present, has_items_name},
                 {:data_not_present, no_items_name}
               ]}

            {type, [_ | _] = values} when type in @choice_types ->
              prefix = variant_opts[:prefix] || "#{data_name}-"

              {variants_names, variants_specs} =
                values
                |> Enum.reverse()
                |> Enum.reduce({variants, []}, fn value, {variants_names, variants_specs} ->
                  name = "#{prefix}#{value}"
                  {[name | variants_names], [{:data_with_value, name, value} | variants_specs]}
                end)

              {:choice, variants_names, variants_specs}

            {_type, _} ->
              not_nil_name = variant_opts[:not_nil] || data_name
              nil_name = variant_opts[nil] || "no-#{data_name}"

              {:other, [not_nil_name, nil_name | variants],
               [
                 {:data_present, not_nil_name},
                 {:data_not_present, nil_name}
               ]}
          end

        {all_variants, [{type, spec.func, spec.name, data_name, assign_ast, variants_specs} | data_variants]}
    end
  end

  def enum_types, do: @enum_types
  def choice_types, do: @choice_types

  defp normalize_variant_name(name) when is_atom(name) do
    name
    |> to_string()
    |> String.replace(["_", "!", "?"], fn
      "_" -> "-"
      _ -> ""
    end)
  end
end
