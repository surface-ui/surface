defmodule Surface.ComponentTest do
  use Surface.ConnCase, async: true
  import Phoenix.ConnTest

  defmodule Stateless do
    use Surface.Component

    prop label, :string, default: ""
    prop class, :css_class

    def render(assigns) do
      ~F"""
      <div class={@class}>
        <span>{@label}</span>
      </div>
      """
    end
  end

  defmodule Outer do
    use Surface.Component

    slot default

    def render(assigns) do
      ~F"""
      <div><#slot/></div>
      """
    end
  end

  defmodule Inner do
    use Surface.Component

    def render(assigns) do
      ~F"""
      <span>Inner</span>
      """
    end
  end

  defmodule OuterWithSlotArg do
    use Surface.Component

    slot default, arg: %{info: :string}

    def render(assigns) do
      info = "My info"

      ~F"""
      <div><#slot {@default, info: info}/></div>
      """
    end
  end

  defmodule ViewWithStateless do
    use Surface.LiveView

    def render(assigns) do
      ~F"""
      <Stateless label="My label" class="myclass"/>
      """
    end
  end

  defmodule ViewWithNested do
    use Surface.LiveView

    def render(assigns) do
      ~F"""
      <Outer>
        <Inner/>
      </Outer>
      """
    end
  end

  defmodule ViewWithSlotArg do
    use Surface.LiveView

    def render(assigns) do
      ~F"""
      <OuterWithSlotArg :let={info: my_info}>
        {my_info}
      </OuterWithSlotArg>
      """
    end
  end

  defmodule StatelessWithId do
    use Surface.Component

    prop id, :string

    def render(assigns) do
      ~F"""
      <div>{@id}</div>
      """
    end
  end

  defmodule StatelessWithIdAndUpdate do
    use Surface.Component

    prop id, :string
    data id_copy, :string

    defp update(assigns) do
      assign(assigns, :id_copy, assigns.id)
    end

    @impl true
    def render(assigns) do
      assigns = update(assigns)

      ~F"""
      <div>{@id} - {@id_copy}</div>
      """
    end
  end

  defmodule ViewWithStatelessWithId do
    use Surface.LiveView

    def render(assigns) do
      ~F"""
      <StatelessWithId id="my_id" />
      """
    end
  end

  defmodule ViewWithStatelessWithIdAndUpdate do
    use Surface.LiveView

    def render(assigns) do
      ~F"""
      <StatelessWithIdAndUpdate id="my_id" />
      """
    end
  end

  defmodule Recursive do
    use Surface.Component

    prop list, :list
    prop count, :integer, default: 1
    data item, :any
    data rest, :list

    def render(%{list: [item | rest]} = assigns) do
      assigns =
        assigns
        |> assign(:item, item)
        |> assign(:rest, rest)

      ~F"""
      {@count}. {@item}
      <Recursive list={@rest} count={@count + 1}/>
      """
    end

    def render(assigns), do: ~F""
  end

  test "render recursive components" do
    html =
      render_surface do
        ~F"""
        <Recursive list={["a", "b", "c"]}/>
        """
      end

    assert html =~ """
           1. a
           2. b
           3. c
           """
  end

  test "render dynamic components" do
    alias Surface.Components.Dynamic.Component

    assigns = %{module: Stateless, label: "my label", class: [myclass: true]}

    html =
      render_surface do
        ~F"""
        <Component module={@module} label={@label} class={@class}/>
        """
      end

    assert html =~ """
           <div class="myclass">
             <span>my label</span>
           </div>
           """
  end

  test "raise compile error if option :slot is not a string" do
    id = :erlang.unique_integer([:positive]) |> to_string()
    module = "TestSlotWithoutSlotName_#{id}"

    code = """
    defmodule #{module} do
      use Surface.Component, slot: {1, 2}

      prop label, :string
    end
    """

    message =
      ~r"code.exs:2:\n#{maybe_ansi("error:")} invalid value for option :slot. Expected a string, got: {1, 2}"

    assert_raise(Surface.CompileError, message, fn ->
      {{:module, _, _, _}, _} = Code.eval_string(code, [], %{__ENV__ | file: "code.exs", line: 1})
    end)
  end

  describe "With LiveView" do
    test "render stateless component" do
      {:ok, _view, html} = live_isolated(build_conn(), ViewWithStateless)

      assert html =~ """
             <div class="myclass"><span>My label</span></div>\
             """
    end

    test "stateless component with id should not become stateful" do
      {:ok, _view, html} = live_isolated(build_conn(), ViewWithStatelessWithId)

      # Stateful components are rendered as <div data-phx-component="...">
      assert html =~ """
             <div>my_id</div>\
             """
    end

    test "stateless component with id and implementing update/2 should not become stateful" do
      {:ok, _view, html} = live_isolated(build_conn(), ViewWithStatelessWithIdAndUpdate)

      # Stateful components are rendered as <div data-phx-component="...">
      assert html =~ """
             <div>my_id - my_id</div>\
             """
    end

    test "render nested component's content" do
      {:ok, _view, html} = live_isolated(build_conn(), ViewWithNested)

      assert html =~ """
             <div><span>Inner</span></div>\
             """
    end

    test "render content with slot arg" do
      {:ok, _view, html} = live_isolated(build_conn(), ViewWithSlotArg)

      assert html =~ """
             <div>
               My info
             </div>\
             """
    end
  end

  describe "Without LiveView" do
    test "render stateless component" do
      html =
        render_surface do
          ~F"""
          <Stateless label="My label" class="myclass"/>
          """
        end

      assert html =~ """
             <div class="myclass">
               <span>My label</span>
             </div>
             """
    end

    test "render nested component's content" do
      html =
        render_surface do
          ~F"""
          <Outer>
            <Inner/>
          </Outer>
          """
        end

      assert html =~ """
             <div>
               <span>Inner</span>
             </div>
             """
    end

    test "render content with slot arg" do
      html =
        render_surface do
          ~F"""
          <OuterWithSlotArg :let={info: my_info}>
            {my_info}
          </OuterWithSlotArg>
          """
        end

      assert html =~ """
             <div>
               My info
             </div>
             """
    end

    test "render error message if module is not a component", %{conn: conn} do
      import ExUnit.CaptureIO

      code =
        quote do
          ~F"""
          <div>
            <Enum/>
          </div>
          """
        end

      output =
        capture_io(:standard_error, fn ->
          module = compile_surface(code)
          {:ok, _view, html} = live_isolated(conn, module)

          assert html =~ """
                 <div><span style="color: red; border: 2px solid red; padding: 3px"> \
                 Error: cannot render &lt;Enum&gt; (module Enum is not a component)\
                 </span></div>\
                 """
        end)

      assert output =~ "cannot render <Enum> (module Enum is not a component)"
      assert output =~ "code:2:"
    end
  end

  describe "components in dead views" do
    defmodule DeadView do
      use Phoenix.Template, root: "support/dead_views"
      import Surface

      def render("index.html", assigns) do
        ~F"""
        <Outer><Stateless label="My label" class="myclass"/></Outer>
        """
      end
    end

    test "renders the component" do
      assert Phoenix.Template.render_to_string(DeadView, "index", "html", []) =~
               """
               <div><div class="myclass">
                 <span>My label</span>
               </div>
               </div>
               """
    end
  end

  defmodule ComponentWithoutCompileTimeDeps do
    use Surface.Component

    def render(assigns) do
      ~F"""
      <Stateless label="My label" class="myclass"/>
      <Outer>
        <Inner/>
      </Outer>
      """
    end

    def __compile_time_deps__() do
      Enum.reverse(@__compile_time_deps__)
    end
  end

  defmodule ComponentWithCompileTimeDeps do
    use Surface.Component

    use Surface.ComponentTest.Stateless
    use Surface.ComponentTest.Outer, as: AliasedOuter
    use Inner

    def render(assigns) do
      ~F"""
      <Stateless label="My label" class="myclass"/>
      <AliasedOuter>
        <Inner/>
      </AliasedOuter>
      """
    end

    def __compile_time_deps__() do
      Enum.reverse(@__compile_time_deps__)
    end
  end

  test "component with compile-time deps" do
    assert ComponentWithoutCompileTimeDeps.__compile_time_deps__() == []

    assert ComponentWithCompileTimeDeps.__compile_time_deps__() == [
             Surface.ComponentTest.Stateless,
             Surface.ComponentTest.Outer,
             Surface.ComponentTest.Inner
           ]
  end
end
