defmodule Surface.LiveViewTest do
  @moduledoc """
  Conveniences for testing Surface components.
  """

  alias Surface.Catalogue

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

  @doc """
  This macro generates ExUnit test cases for catalogue examples.

  The tests will automatically assert if the example was successfully rendered.

  Pay attention that, by default, the generated tests don't test how the components should look like.
  However, it makes sure the examples are not raising exceptions at runtime, for instance, due to
  changes in the component's API.

  ## Usage

  The `catalogue_test/1` macro accepts a single argument which can one of:

  * A component module (subject), which will generate tests for all examples/playgrounds found
    for that component.
  * The atom `:all`, which will generate tests for all examples/playgrounds found for ALL components
    in the project.

  Keep in mind that you should either use individual `catalogue_test/1` calls for each
  component or use `:all`. Otherwise, you will end up with duplicated tests.

  ### Options

    * `except` - A list of modules that should be excluded. This option only applies when using `:all`.

  ## Examples

  Generating tests for components' examples:

      defmodule MyProject.Components.ButtonTest do
        use MyProject.ConnCase, async: true

        catalogue_test MyProject.Components.Button
      end

  Generating tests for all avaiable components:

      defmodule MyProject.Components.CatalogueTest do
        use MyProject.ConnCase, async: true

        catalogue_test :all
      end

  Generating tests for all avaiable components except `MyComponent`:

      defmodule MyProject.Components.CatalogueTest do
        use MyProject.ConnCase, async: true

        catalogue_test :all, except: [MyComponent]
      end

  """
  defmacro catalogue_test(module_or_all, opts \\ []) do
    module_or_all = Macro.expand(module_or_all, __CALLER__)
    except = Keyword.get(opts, :except, []) |> Enum.map(&Macro.expand(&1, __CALLER__))
    {examples, playgrounds} = get_examples_and_playgrouds(module_or_all, except)

    playground_tests =
      for view <- playgrounds do
        config = Catalogue.get_config(view)
        title = Keyword.get(config, :title)
        test_name = if title, do: "#{inspect(view)} - #{title}", else: inspect(view)
        file = view.module_info() |> get_in([:compile, :source]) |> to_string()

        quote line: 1 do
          @file unquote(file)
          test unquote(test_name) do
            assert {:ok, _view, html} = live_isolated(build_conn(), unquote(view))
          end
        end
      end

    examples_tests =
      for view <- examples,
          config <- Surface.Catalogue.get_metadata(view).examples_configs do
        func = Keyword.get(config, :func) |> to_string()
        line = Keyword.get(config, :line) || 1
        assert_texts = Keyword.get(config, :assert, []) |> List.wrap()
        test_name = "#{inspect(view)}.#{func}"
        file = view.module_info() |> get_in([:compile, :source]) |> to_string()

        assert_live_ast =
          quote line: line do
            assert {:ok, _view, html} =
                     live_isolated(build_conn(), unquote(view), session: %{"func" => unquote(func)})
          end

        assert_texts_ast =
          for text <- assert_texts do
            quote line: line do
              assert html =~ unquote(text)
            end
          end

        quote do
          @file unquote(file)
          test unquote(test_name) do
            unquote(assert_live_ast)
            unquote(assert_texts_ast)
          end
        end
      end

    playground_tests ++ examples_tests
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

  defp get_examples_and_playgrouds(module_or_all, except) do
    components =
      case {module_or_all, except} do
        {:all, []} ->
          Surface.components(only_current_project: true)

        {:all, except} ->
          Surface.components(only_current_project: true)
          |> Enum.filter(fn c -> Surface.Catalogue.get_metadata(c)[:subject] not in except end)

        {module, _} when is_atom(module) ->
          Surface.components(only_current_project: true)
          |> Enum.filter(fn c -> Surface.Catalogue.get_metadata(c)[:subject] == module end)

        {value, _} ->
          raise(ArgumentError, "catalogue_test/1 expects either a module or `:all`, got #{inspect(value)}")
      end

    %{playground: playgrounds, example: examples} =
      components
      |> Enum.group_by(&Surface.Catalogue.get_metadata(&1)[:type])
      |> Map.put_new(:example, %{})
      |> Map.put_new(:playground, %{})

    {examples, playgrounds}
  end
end
