defmodule Surface.LiveViewTest do
  @moduledoc """
  Conveniences for testing Surface components.
  """

  defmodule BlockWrapper do
    @moduledoc false

    use Phoenix.Component

    def render(assigns) do
      ~H[<%= render_slot(@inner_block) %>]
    end
  end

  defmacro __using__(_opts) do
    quote do
      import Phoenix.ConnTest
      import Phoenix.LiveViewTest
      import Phoenix.LiveView.Helpers, only: [live_component: 2, live_component: 3, component: 2]
      import Surface, only: [sigil_F: 2]
      import Surface.LiveViewTest
    end
  end

  @doc """
  Render Surface code.

  Use this macro when testing regular rendering of stateless components or live components
  that don't require a parent live view during the tests.

  For tests depending on the existence of a parent live view, e.g. testing events on live
  components and its side-effects, you need to use either `Phoenix.LiveViewTest.live/2` or
  `Phoenix.LiveViewTest.live_isolated/3`.

  ## Example

      html =
        render_surface do
          ~F"\""
          <Link label="user" to="/users/1" />
          "\""
        end

      assert html =~ "\""
            <a href="/users/1">user</a>
            "\""

  """
  defmacro render_surface(do: do_block) do
    clauses =
      quote do
        _ ->
          unquote(do_block)
      end

    inner_block_assigns =
      quote do
        %{
          __slot__: :inner_block,
          inner_block: Phoenix.LiveView.Helpers.inner_block(:inner_block, do: unquote(clauses))
        }
      end

    render_component_call =
      quote do
        Phoenix.LiveViewTest.render_component(
          &Surface.LiveViewTest.BlockWrapper.render/1,
          %{
            inner_block: unquote(inner_block_assigns),
            __context__: %{}
          }
        )
      end

    if Macro.Env.has_var?(__CALLER__, {:assigns, nil}) do
      quote do
        var!(assigns) = Map.merge(var!(assigns), %{__context__: %{}})
        unquote(render_component_call) |> Surface.LiveViewTest.clean_html()
      end
    else
      quote do
        var!(assigns) = %{__context__: %{}}
        unquote(render_component_call) |> Surface.LiveViewTest.clean_html()
      end
    end
  end

  @doc """
  Compiles Surface code into a new LiveView module.

  This macro should be used sparingly as it always generates and compiles a new module
  on-the-fly, which can potentially slow down your test suite.

  Its main use is when testing compile-time errors/warnings.

  ## Example

      code =
        quote do
          ~F"\""
          <KeywordProp prop="some string"/>
          "\""
        end

      message =
        ~S(code:1: invalid value for property "prop". Expected a :keyword, got: "some string".)

      assert_raise(CompileError, message, fn ->
        compile_surface(code)
      end)

  """
  defmacro compile_surface(code, assigns \\ quote(do: %{})) do
    env = Map.take(__CALLER__, [:function, :module, :line])

    quote do
      ast =
        unquote(__MODULE__).generate_live_view_ast(
          unquote(code),
          unquote(assigns),
          unquote(Macro.escape(env))
        )

      {{:module, module, _, _}, _} = Code.eval_quoted(ast, [], %{__ENV__ | file: "code", line: 0})

      module
    end
  end

  @doc """
  Wraps a test code so it runs using a custom configuration for a given component.

  Tests using this macro should run synchronously. A warning is shown if the test
  case is configured as `async: true`.

  ## Example

      using_config TextInput, default_class: "default_class" do
        html =
          render_surface do
            ~F"\""
            <TextInput/>
            "\""
          end

        assert html =~ ~r/class="default_class"/
      end

  """
  defmacro using_config(component, config, do: block) do
    if Module.get_attribute(__CALLER__.module, :ex_unit_async) do
      message = """
      Using `using_config` with `async: true` might lead to race conditions.

      Please set `async: false` on the test module.
      """

      Surface.IOHelper.warn(message, __CALLER__)
    end

    quote do
      component = unquote(component)
      old_config = Application.get_env(:surface, :components, [])
      value = unquote(config)
      new_config = Keyword.update(old_config, component, value, fn _ -> value end)
      Application.put_env(:surface, :components, new_config)

      try do
        unquote(block)
      after
        Application.put_env(:surface, :components, old_config)
      end
    end
  end

  @doc false
  def generate_live_view_ast(render_code, props, env) do
    {func, _} = env.function
    module = Module.concat([env.module, String.replace("(#{func}) at line #{env.line}", "/", "_")])

    props_ast =
      for {name, _} <- props do
        quote do
          prop unquote(Macro.var(name, nil)), :any
        end
      end

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
  end

  @doc false
  def clean_html(html) do
    html
    |> String.replace(~r/\n+/, "\n")
    |> String.replace(~r/\n\s+\n/, "\n")
  end
end
