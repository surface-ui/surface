ExUnit.start()

defmodule Router do
  use Phoenix.Router
end

defmodule Endpoint do
  use Phoenix.Endpoint, otp_app: :surface
  plug(Router)
end

Application.put_env(:surface, Endpoint,
  secret_key_base: "J4lTFt000ENUVhu3dbIB2P2vRVl2nDBH6FLefnPUImL8mHYNX8Kln/N9J0HH19Mq",
  live_view: [
    signing_salt: "LfCCMxfkGME8S8P8XU3Z6/7+ZlD9611u"
  ]
)

Endpoint.start_link()

defmodule ComponentTestHelper do
  require Phoenix.LiveViewTest

  @endpoint Endpoint

  def render_static(code) do
    code
    |> Phoenix.HTML.Safe.to_iodata()
    |> IO.iodata_to_binary()
    |> String.replace(~r/\n+/, "\n")
  end

  def normalize_html(html) do
    html
    |> String.split("\n")
    |> Enum.map(&String.trim(&1))
    |> Enum.join("")
  end

  defmacro assert_html({op, meta, [lhs, rhs]}) do
    new_lhs = quote do: normalize_html(unquote(lhs))
    new_rhs = quote do: normalize_html(unquote(rhs))

    quote do
      assert unquote({op, meta, [new_lhs, new_rhs]})
    end
  end

  defmacro render_live(code, assigns \\ quote(do: %{})) do
    quote do
      render_live(unquote(code), unquote(assigns), unquote(Macro.escape(__CALLER__)))
    end
  end

  def render_live(render_code, props, env) do
    {func, _} = env.function
    module = Module.concat([env.module, "(#{func}) at line #{env.line}"])

    props_ast =
      for {name, _} <- props do
        quote do
          prop unquote(Macro.var(name, nil)), :any
        end
      end

    ast =
      quote do
        defmodule unquote(module) do
          use Surface.LiveView

          unquote_splicing(props_ast)

          def render(var!(assigns)) do
            var!(assigns) = Map.merge(var!(assigns), unquote(Macro.escape(props)))
            unquote(render_code)
          end
        end
      end

    {{:module, module, _, _}, _} = Code.eval_quoted(ast, [], %{env | file: "code", line: 0})
    conn = Phoenix.ConnTest.build_conn()
    {:ok, _view, html} = Phoenix.LiveViewTest.live_isolated(conn, module)

    clean_html(html)
  end

  def extract_line(message) do
    case Regex.run(~r/.exs:(\d+)/, message) do
      [_, line] ->
        String.to_integer(line)

      _ ->
        :not_found
    end
  end

  defmacro using_config(component, config, do: block) do
    if Module.get_attribute(__CALLER__.module, :ex_unit_async) do
      message = """
      Using `using_config` with `async: true` might lead to race conditions.

      Please set `async: false` on the test module.
      """

      Surface.IOHelper.warn(message, __CALLER__, & &1)
    end

    quote do
      component = unquote(component)
      old_config = Application.get_env(:surface, :components, [])
      value = unquote(config)
      new_config = Keyword.update(old_config, component, value, fn _ -> value end)
      Application.put_env(:surface, :components, new_config)
      recompile(component)

      try do
        unquote(block)
      after
        Application.put_env(:surface, :components, old_config)
        recompile(component)
      end
    end
  end

  def recompile(module) do
    ExUnit.CaptureIO.capture_io(:standard_error, fn ->
      module.module_info(:compile)
      |> Keyword.fetch!(:source)
      |> to_string()
      |> Code.compile_file()
    end)

    :ok
  end

  defp clean_html(html) do
    html
    |> String.replace(~r/^<div.+>/U, "")
    |> String.replace(~r/<\/div>$/, "\n")
    |> String.replace(~r/\n+/, "\n")
    |> String.replace(~r/\n\s+\n/, "\n")
  end
end
