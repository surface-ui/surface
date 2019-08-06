defmodule Surface.Engine do
  @moduledoc """
  This is an implementation of EEx.Engine that guarantees
  templates are HTML Safe.

  The `encode_to_iodata!/1` function converts the rendered
  template result into iodata.
  """

  @behaviour EEx.Engine

  @anno (if :erlang.system_info(:otp_release) >= '19' do
           [generated: true]
         else
           [line: -1]
         end)

  @doc """
  Encodes the HTML templates to iodata.
  """
  def encode_to_iodata!({:safe, body}), do: body
  def encode_to_iodata!(body) when is_binary(body), do: Plug.HTML.html_escape(body)
  def encode_to_iodata!(other), do: Phoenix.HTML.Safe.to_iodata(other)

  @impl true
  def init(opts) do
    %{
      iodata: [],
      dynamic: [],
      vars_count: 0,
      assigns_var: opts[:assigns_var]
    }
  end

  @impl true
  def handle_begin(state) do
    %{state | iodata: [], dynamic: []}
  end

  @impl true
  def handle_end(quoted) do
    handle_body(quoted)
  end

  @impl true
  def handle_body(state) do
    %{iodata: iodata, dynamic: dynamic} = state
    safe = {:safe, Enum.reverse(iodata)}
    {:__block__, [], Enum.reverse([safe | dynamic])}
  end

  @impl true
  def handle_text(state, text) do
    %{iodata: iodata} = state
    %{state | iodata: [text | iodata]}
  end

  @impl true
  def handle_expr(state, "=", ast) do
    %{iodata: iodata, dynamic: dynamic, vars_count: vars_count, assigns_var: assigns_var} = state
    ast = traverse(ast, assigns_var)
    var = Macro.var(:"arg#{vars_count}", __MODULE__)
    ast = quote do: unquote(var) = unquote(to_safe(ast))
    %{state | dynamic: [ast | dynamic], iodata: [var | iodata], vars_count: vars_count + 1}
  end

  def handle_expr(state, "", ast) do
    %{dynamic: dynamic, assigns_var: assigns_var} = state
    ast = traverse(ast, assigns_var)
    %{state | dynamic: [ast | dynamic]}
  end

  def handle_expr(state, marker, ast) do
    EEx.Engine.handle_expr(state, marker, ast)
  end

  ## Safe conversion

  defp to_safe(ast) do
    to_safe(ast, line_from_expr(ast))
  end

  defp line_from_expr({_, meta, _}) when is_list(meta), do: Keyword.get(meta, :line)
  defp line_from_expr(_), do: nil

  # We can do the work at compile time
  defp to_safe(literal, _line) when is_binary(literal) or is_atom(literal) or is_number(literal) do
    Phoenix.HTML.Safe.to_iodata(literal)
  end

  # We can do the work at runtime
  defp to_safe(literal, line) when is_list(literal) do
    quote line: line, do: Phoenix.HTML.Safe.List.to_iodata(unquote(literal))
  end

  # We need to check at runtime and we do so by optimizing common cases.
  defp to_safe(expr, line) do
    # Keep stacktraces for protocol dispatch and coverage
    safe_return = quote line: line, do: data
    bin_return = quote line: line, do: Plug.HTML.html_escape_to_iodata(bin)
    other_return = quote line: line, do: Phoenix.HTML.Safe.to_iodata(other)

    # However ignore them for the generated clauses to avoid warnings
    quote @anno do
      case unquote(expr) do
        {:safe, data} -> unquote(safe_return)
        bin when is_binary(bin) -> unquote(bin_return)
        other -> unquote(other_return)
      end
    end
  end

  ## Traversal

  defp traverse(expr, assigns_var) do
    {ast, _} = Macro.prewalk(expr, assigns_var, &handle_assign/2)
    ast
  end

  defp handle_assign({:@, meta, [{name, _, atom}]}, assigns_var) when is_atom(name) and is_atom(atom) do
    var = Macro.var(assigns_var, nil)
    ast =
      quote line: meta[:line] || 0 do
        # Phoenix.HTML.Engine.fetch_assign!(Macro.escape({unquote(assigns_var), [], Elixir}), unquote(name))
        Phoenix.HTML.Engine.fetch_assign!(var!(unquote(var)), unquote(name))
        # Phoenix.HTML.Engine.fetch_assign!(var!(assigns), unquote(name))
      end
    {ast, assigns_var}
  end

  defp handle_assign(arg, assigns_var), do: {arg, assigns_var}

  @doc false
  def fetch_assign!(assigns, key) do
    case Access.fetch(assigns, key) do
      {:ok, val} ->
        val

      :error ->
        raise ArgumentError, """
        assign @#{key} not available in eex template.

        Please make sure all proper assigns have been set. If this
        is a child template, ensure assigns are given explicitly by
        the parent template as they are not automatically forwarded.

        Available assigns: #{inspect(Enum.map(assigns, &elem(&1, 0)))}
        """
    end
  end
end

# defmodule Surface.Engine do
#   alias Surface.Parser

#   def compile(path, _name) do
#     template =
#       path
#       |> File.read!()
#       |> Parser.parse(1)
#       |> Parser.to_iolist(__ENV__)
#       |> IO.iodata_to_binary()
#       |> EEx.compile_string(engine: Phoenix.HTML.Engine, line: 1)

#     quote do
#       # import Surface.Parser

#       temple do: unquote(template)
#     end
#   end
# end
