defmodule Surface.FunctionComponentTest do
  use Surface.ConnCase, async: true

  import Phoenix.Component
  import ExUnit.CaptureIO

  defmodule ComponentWithFunc do
    use Surface.Component

    def render(assigns) do
      ~F"""
      <.func id="123"/>
      <ComponentWithFunc.func id="123"/>
      """
    end

    def func(assigns) do
      ~F[{@id}]
    end
  end

  defmodule ViewWithComponentWithFunc do
    use Surface.LiveView

    def render(assigns) do
      ~F"""
      <ComponentWithFunc/>
      """
    end
  end

  defmodule NotAComponent do
    def func(assigns) do
      ~F"""
      Label: {@label}
      {render_slot(@inner_block)}
      """
    end
  end

  defmodule Stateless do
    use Surface.Component

    prop label, :string, default: ""

    def render(assigns) do
      ~F"""
      <span>Stateless label: {@label}</span>
      """
    end
  end

  defmodule Stateful do
    use Surface.LiveComponent

    prop label, :string, default: ""

    def render(assigns) do
      ~F"""
      <span>Stateful label: {@label}</span>
      """
    end
  end

  defp priv_func_with_assigns(assigns) do
    ~F"""
    <div>
      Private function with assigns
      Label: {@label}
      Title: {@title}
    </div>
    """
  end

  defp priv_func_containing_other_components(assigns) do
    ~F"""
    <div>
      Private function containing other components
      <Stateless label="stateless"/>
      <Stateful id="stateful" label="stateful"/>
    </div>
    """
  end

  defp priv_func_with_inner_block(assigns) do
    ~F"""
    <div>
      {render_slot(@inner_block)}
    </div>
    """
  end

  defp priv_func_with_inner_block_and_arg(assigns) do
    ~F"""
    <div>
      {render_slot(@inner_block, "my_item")}
    </div>
    """
  end

  def public_func_with_assigns(assigns) do
    ~F"""
    <div>
      Public function with assigns
      Label: {@label}
      Title: {@title}
    </div>
    """
  end

  def public_func_containing_other_components(assigns) do
    ~F"""
    <div>
      Public function containing other components
      <Stateless label="stateless"/>
      <Stateful id="stateful" label="stateful"/>
    </div>
    """
  end

  def public_func_with_inner_block(assigns) do
    ~F"""
    <div>
      {render_slot(@inner_block)}
    </div>
    """
  end

  def public_func_with_inner_block_and_map_arg(assigns) do
    ~F"""
    <div>
      {render_slot(@inner_block, %{item: "my_item", count: 1})}
    </div>
    """
  end

  def public_func_with_inner_block_and_keyword_arg(assigns) do
    ~F"""
    <div>
      {render_slot(@inner_block, item: "my_item_1", item: "my_item_2")}
    </div>
    """
  end

  test "dynamic props" do
    expected = """
    <div>
      Private function with assigns
      Label: my label
      Title: my title
    </div>
    """

    html =
      render_surface do
        ~F"""
        <.priv_func_with_assigns :props={label: "my label", title: "my title"}/>
        """
      end

    assert html =~ expected

    html =
      render_surface do
        ~F"""
        <.priv_func_with_assigns {...[label: "my label", title: "my title"]}/>
        """
      end

    assert html =~ expected
  end

  test "assigning props with {= }" do
    assigns = %{label: "my label", title: "my title"}

    html =
      render_surface do
        ~F"""
        <.priv_func_with_assigns {=@label} {=@title}/>
        """
      end

    assert html =~ """
           <div>
             Private function with assigns
             Label: my label
             Title: my title
           </div>
           """
  end

  test "render private function component containing other components" do
    html =
      render_surface do
        ~F"""
        <.priv_func_containing_other_components/>
        """
      end

    assert html =~ """
           <div>
             Private function containing other components
             <span>Stateless label: stateless</span>
             <span>Stateful label: stateful</span>
           </div>
           """
  end

  test "render private function component with inner block" do
    html =
      render_surface do
        ~F"""
        <.priv_func_with_inner_block>
          <Stateless label="stateless"/>
          <Stateful id="stateful" label="stateful"/>
        </.priv_func_with_inner_block>
        """
      end

    assert html =~ """
           <div>
             <span>Stateless label: stateless</span>
             <span>Stateful label: stateful</span>
           </div>
           """
  end

  test "render private function component with inner block and arg" do
    html =
      render_surface do
        ~F"""
        <.priv_func_with_inner_block_and_arg :let={item}>
          Arg: {item}
        </.priv_func_with_inner_block_and_arg>
        """
      end

    assert html =~ """
           <div>
             Arg: my_item
           </div>
           """
  end

  test "render public function components with dynamic props" do
    expected = """
    <div>
      Public function with assigns
      Label: my label
      Title: my title
    </div>
    """

    html =
      render_surface do
        ~F"""
        <Surface.FunctionComponentTest.public_func_with_assigns :props={label: "my label", title: "my title"}/>
        """
      end

    assert html =~ expected

    html =
      render_surface do
        ~F"""
        <Surface.FunctionComponentTest.public_func_with_assigns {...[label: "my label", title: "my title"]}/>
        """
      end

    assert html =~ expected
  end

  test "render public function components assigning props with {= }" do
    assigns = %{label: "my label", title: "my title"}

    html =
      render_surface do
        ~F"""
        <Surface.FunctionComponentTest.public_func_with_assigns {=@label} {=@title}/>
        """
      end

    assert html =~ """
           <div>
             Public function with assigns
             Label: my label
             Title: my title
           </div>
           """
  end

  test "render public function component containing other components" do
    html =
      render_surface do
        ~F"""
        <Surface.FunctionComponentTest.public_func_containing_other_components/>
        """
      end

    assert html =~ """
           <div>
             Public function containing other components
             <span>Stateless label: stateless</span>
             <span>Stateful label: stateful</span>
           </div>
           """
  end

  test "render public function component with inner block" do
    html =
      render_surface do
        ~F"""
        <Surface.FunctionComponentTest.public_func_with_inner_block>
          <Stateless label="stateless"/>
          <Stateful id="stateful" label="stateful"/>
        </Surface.FunctionComponentTest.public_func_with_inner_block>
        """
      end

    assert html =~ """
           <div>
             <span>Stateless label: stateless</span>
             <span>Stateful label: stateful</span>
           </div>
           """
  end

  test "render public function component with inner block and map arg" do
    html =
      render_surface do
        ~F"""
        <Surface.FunctionComponentTest.public_func_with_inner_block_and_map_arg :let={item: item}>
          Arg: {item}
        </Surface.FunctionComponentTest.public_func_with_inner_block_and_map_arg>
        """
      end

    assert html =~ """
           <div>
             Arg: my_item
           </div>
           """
  end

  test "render public function component with inner block and keyword arg" do
    html =
      render_surface do
        ~F"""
        <Surface.FunctionComponentTest.public_func_with_inner_block_and_keyword_arg :let={[item: item1, item: item2]}>
          Arg 1: {item1}
          Arg 2: {item2}
        </Surface.FunctionComponentTest.public_func_with_inner_block_and_keyword_arg>
        """
      end

    assert html =~ """
           <div>
             Arg 1: my_item_1
             Arg 2: my_item_2
           </div>
           """
  end

  describe "dynamic function components" do
    alias Surface.Components.Dynamic.Component

    test "render dynamic public function component with inner block and arg" do
      html =
        render_surface do
          ~F"""
          <Component
            module={Surface.FunctionComponentTest}
            function={:public_func_with_inner_block_and_map_arg}
            :let={item: item}
          >
            Arg: {item}
          </Component>
          """
        end

      assert html =~ """
             <div>
               Arg: my_item
             </div>
             """
    end

    test "render dynamic public function component with inner block and arg without :let" do
      html =
        render_surface do
          ~F"""
          <Component
            module={Surface.FunctionComponentTest}
            function={:public_func_with_inner_block_and_map_arg}
          >
            Arg
          </Component>
          """
        end

      assert html =~ """
             <div>
               Arg
             </div>
             """
    end
  end

  test "render imported public function component" do
    import NotAComponent, only: [func: 1]

    html =
      render_surface do
        ~F"""
        <.func label="my label">
        my content
        </.func>
        """
      end

    assert html =~ """
           Label: my label
           my content
           """
  end

  test "don't warn on unknown attributes of function components" do
    output =
      capture_io(:standard_error, fn ->
        {:ok, _view, _html} = live_isolated(build_conn(), ViewWithComponentWithFunc)
      end)

    refute output == ~S(Unknown property "id")
  end
end
