defmodule Surface.Style.SassProcessor do
  @behaviour Surface.Style.Processor

  @selector_marker ".__sface--selector__"

  @impl true
  def normalize_block({type, _, [code]}) when type in [:css, :scss] do
    code
  end

  def normalize_block(block) do
    block
  end

  @impl true
  def normalize_opts(opts) do
    vars = normalize_vars(opts[:vars] || [])
    Keyword.put(opts, :vars, vars)
  end

  @impl true
  def process(code, opts, caller) do
    vars = opts |> Keyword.get(:vars, []) |> maybe_add_default_to_vars(caller)

    sass = """
    #{@selector_marker} {
    #{code}
    }
    """

    case Sass.compile(sass, %{output_style: Sass.sass_style_expanded()}) do
      {:ok, css} ->
        split_css(css, vars, caller)

      {:error, message} ->
        [_, desc, line, error_code] =
          Regex.run(~r/^(.+?)\s+on line (\d+) of stdin\s+(.+)/s, message)

        {:error, desc <> "\n\n" <> error_code, String.to_integer(line)}
    end
  end

  defp split_css(css, vars, caller) do
    # TODO: Split static ($*) and dynamic (--*)
    dynamic_vars = vars
    dynamic_vars_with_default = dynamic_vars |> Enum.filter(fn v -> v.default end)
    dynamic_var_calls = Enum.map(dynamic_vars, fn v -> "var(#{v.name})" end)

    dynamic_var_calls_with_default =
      Enum.map(dynamic_vars_with_default, fn v -> "var(#{v.name})" end)

    lines = String.split(css, "\n")
    dynamic_root = ~S([data-phx-component="<%= @myself %>"])
    static_root = ~s([data-sface-module="#{inspect(caller.module)}"])

    acc = {[], [], [], [], nil}

    {static_parts, dynamic_parts, _, _, _} =
      Enum.reduce(lines, acc, fn str, {static, dynamic, static_tmp, dynamic_tmp, selector} ->
        case str do
          @selector_marker <> _ = selector ->
            {static, dynamic, [], [], selector}

          "}" ->
            static =
              if static_tmp == [] do
                static
              else
                new_selector = String.replace(selector, @selector_marker, static_root)
                section =
                  [new_selector | Enum.reverse(["}" | static_tmp])] |> Enum.join("\n")

                [section | static]
              end

            dynamic =
              if dynamic_tmp == [] do
                dynamic
              else
                new_selector = String.replace(selector, @selector_marker, dynamic_root)
                section =
                  [new_selector | Enum.reverse(["}" | dynamic_tmp])]
                  |> Enum.join("\n")

                [section | dynamic]
              end

            {static, dynamic, [], [], nil}

          _ ->
            cond do
              String.contains?(str, dynamic_var_calls_with_default) ->
                {static, dynamic, [str | static_tmp], [str | dynamic_tmp], selector}

              String.contains?(str, dynamic_var_calls) ->
                {static, dynamic, static_tmp, [str | dynamic_tmp], selector}

              true ->
                {static, dynamic, [str | static_tmp], dynamic_tmp, selector}
            end
        end
      end)

    static = compose_static(caller.module, static_root, static_parts, dynamic_vars_with_default)
    dynamic = compose_dynamic(dynamic_root, dynamic_parts, dynamic_vars)

    {:ok, static, dynamic}
  end

  defp maybe_add_default_to_vars([], _caller) do
    []
  end

  defp maybe_add_default_to_vars(vars, caller) do
    data_assigns = Module.get_attribute(caller.module, :data) || []
    property_assigns = Module.get_attribute(caller.module, :property) || []
    assigns = data_assigns ++ property_assigns

    defaults =
      for %{name: name, opts: opts} <- assigns, into: %{} do
        {name, Keyword.get(opts, :default)}
      end

    Enum.map(vars, fn var -> maybe_add_default_to_var(var, defaults) end)
  end

  defp maybe_add_default_to_var(var, defaults) do
    %{var | default: defaults[var.value]}
  end

  defp static_var_definition(%{name: name, default: default}) do
    "#{name}: #{default};"
  end

  defp dynamic_var_definition(%{name: name, value: assign}) do
    "#{name}: <%= @#{assign} %>;"
  end

  defp normalize_vars(vars) do
    Enum.map(vars, fn var -> normalize_var(var) end)
  end

  defp normalize_var({key, {:^, _, [{assign, _, _}]}}) do
    %{name: to_string(key), value: assign, default: nil}
  end

  defp compose_static(module, static_root, static_parts, dynamic_vars_with_default) do
    static_comment = "/* #{inspect(module)} */\n\n"

    default_dynamic_vars_section =
      if dynamic_vars_with_default == [] do
        ""
      else
        """
        #{static_root} {
          #{Enum.map_join(dynamic_vars_with_default, "\n  ", &static_var_definition/1)}
        }

        """
      end

    if dynamic_vars_with_default == [] and static_parts == [] do
      nil
    else
      static_parts_section = static_parts |> Enum.reverse() |> Enum.join("\n\n")
      static_comment <> default_dynamic_vars_section <> static_parts_section
    end
  end

  defp compose_dynamic(dynamic_root, dynamic_parts, dynamic_vars) do
    if dynamic_vars == [] do
      nil
    else
      dynamic_vars_section = """
      #{dynamic_root} {
        #{Enum.map_join(dynamic_vars, "\n  ", &dynamic_var_definition/1)}
      }

      """
      dynamic_parts_section = dynamic_parts |> Enum.reverse() |> Enum.join("\n\n")
      dynamic_vars_section <> dynamic_parts_section
    end
  end
end
