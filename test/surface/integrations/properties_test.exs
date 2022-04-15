defmodule Surface.PropertiesTest do
  use Surface.ConnCase, async: true

  defmodule StringProp do
    use Surface.Component

    prop label, :string

    def render(assigns) do
      ~F"""
      {@label}
      """
    end
  end

  defmodule AtomProp do
    use Surface.Component

    prop as, :atom

    def render(assigns) do
      ~F"""
      {inspect(@as)}
      """
    end
  end

  defmodule MapProp do
    use Surface.Component

    prop prop, :map

    def render(assigns) do
      ~F"""
      Map?: {is_map(@prop)}
      <span :for={{k, v} <- @prop}>key: {k}, value: {v}</span>
      """
    end
  end

  defmodule ListProp do
    use Surface.Component

    prop prop, :list

    def render(assigns) do
      ~F"""
      List?: {is_list(@prop)}
      <span :for={v <- @prop}>value: {inspect(v)}</span>
      """
    end
  end

  defmodule KeywordProp do
    use Surface.Component

    prop prop, :keyword

    def render(assigns) do
      ~F"""
      Keyword?: {Keyword.keyword?(@prop)}
      <span :for={{k, v} <- @prop}>key: {k}, value: {v}</span>
      """
    end
  end

  defmodule CSSClassProp do
    use Surface.Component

    prop prop, :css_class

    def render(assigns) do
      ~F"""
      <span class={@prop}/>
      """
    end
  end

  defmodule CSSClassPropInspect do
    use Surface.Component

    prop prop, :css_class

    def render(assigns) do
      ~F"""
      <div :for={c <- @prop}>{c}</div>
      """
    end
  end

  defmodule AccumulateProp do
    use Surface.Component

    prop prop, :string, accumulate: true, default: ["default"]

    def render(assigns) do
      ~F"""
      List?: {is_list(@prop)}
      <span :for={v <- @prop}>value: {v}</span>
      """
    end
  end

  defmodule RootProp do
    use Surface.Component

    prop label, :string, root: true

    def render(assigns) do
      ~F"""
      { @label }
      """
    end
  end

  describe "atom" do
    test "passing an atom" do
      html =
        render_surface do
          ~F"""
          <AtomProp as={:some_atom}/>
          """
        end

      assert html =~ ":some_atom"
    end

    test "passing an atom as expression" do
      assigns = %{atom: :some_atom}

      html =
        render_surface do
          ~F"""
          <AtomProp as={@atom}/>
          """
        end

      assert html =~ ":some_atom"
    end

    test "validate invalid atom at compile time" do
      code =
        quote do
          ~F"""
          <AtomProp as="some string"/>
          """
        end

      message = ~S(code:1: invalid value for property "as". Expected a :atom, got: "some string".)

      assert_raise(CompileError, message, fn ->
        compile_surface(code)
      end)
    end
  end

  describe "string" do
    test "passing a string literal" do
      html =
        render_surface do
          ~F"""
          <StringProp label="text"/>
          """
        end

      assert html =~ "text"
    end

    test "passing a string as expression" do
      assigns = %{text: "text"}

      html =
        render_surface do
          ~F"""
          <StringProp label={@text}/>
          """
        end

      assert html =~ "text"
    end
  end

  describe "keyword" do
    test "passing a keyword list" do
      html =
        render_surface do
          ~F"""
          <KeywordProp prop={[option1: 1, option2: 2]}/>
          """
        end

      assert html =~ """
             Keyword?: true
             <span>key: option1, value: 1</span>\
             <span>key: option2, value: 2</span>
             """
    end

    test "passing a keyword list without brackets" do
      html =
        render_surface do
          ~F"""
          <KeywordProp prop={option1: 1, option2: 2}/>
          """
        end

      assert html =~ """
             Keyword?: true
             <span>key: option1, value: 1</span>\
             <span>key: option2, value: 2</span>
             """
    end

    test "passing a keyword list as an expression" do
      assigns = %{submit: [option1: 1, option2: 2]}

      html =
        render_surface do
          ~F"""
          <KeywordProp prop={@submit}/>
          """
        end

      assert html =~ """
             Keyword?: true
             <span>key: option1, value: 1</span>\
             <span>key: option2, value: 2</span>
             """
    end

    test "validate invalid literals at compile-time" do
      code =
        quote do
          ~F"""
          <KeywordProp prop="some string"/>
          """
        end

      message = ~S(code:1: invalid value for property "prop". Expected a :keyword, got: "some string".)

      assert_raise(CompileError, message, fn ->
        compile_surface(code)
      end)
    end

    test "validate invalid values at runtime" do
      message = """
      invalid value for property "prop". Expected a :keyword, got: 1.

      Original expression: {@var}
      """

      assert_raise(RuntimeError, message, fn ->
        assigns = %{var: 1}

        render_surface do
          ~F"""
          <KeywordProp prop={@var}/>
          """
        end
      end)
    end
  end

  describe "map" do
    test "passing a map" do
      html =
        render_surface do
          ~F"""
          <MapProp prop={%{option1: 1, option2: 2}}/>
          """
        end

      assert html =~ """
             Map?: true
             <span>key: option1, value: 1</span>\
             <span>key: option2, value: 2</span>
             """
    end

    test "passing a keyword list" do
      html =
        render_surface do
          ~F"""
          <MapProp prop={[option1: 1, option2: 2]}/>
          """
        end

      assert html =~ """
             Map?: true
             <span>key: option1, value: 1</span>\
             <span>key: option2, value: 2</span>
             """
    end

    test "passing a keyword list without brackets" do
      html =
        render_surface do
          ~F"""
          <MapProp prop={option1: 1, option2: 2}/>
          """
        end

      assert html =~ """
             Map?: true
             <span>key: option1, value: 1</span>\
             <span>key: option2, value: 2</span>
             """
    end

    test "passing a map as an expression" do
      assigns = %{submit: %{option1: 1, option2: 2}}

      html =
        render_surface do
          ~F"""
          <MapProp prop={@submit}/>
          """
        end

      assert html =~ """
             Map?: true
             <span>key: option1, value: 1</span>\
             <span>key: option2, value: 2</span>
             """
    end

    test "passing a keyword list as an expression" do
      assigns = %{submit: [option1: 1, option2: 2]}

      html =
        render_surface do
          ~F"""
          <MapProp prop={@submit}/>
          """
        end

      assert html =~ """
             Map?: true
             <span>key: option1, value: 1</span>\
             <span>key: option2, value: 2</span>
             """
    end

    test "validate invalid literals at compile-time" do
      code =
        quote do
          ~F"""
          <MapProp prop="some string"/>
          """
        end

      message = ~S(code:1: invalid value for property "prop". Expected a :map, got: "some string".)

      assert_raise(CompileError, message, fn ->
        compile_surface(code)
      end)
    end

    test "validate invalid values at runtime" do
      message = """
      invalid value for property "prop". Expected a :map, got: 1.

      Original expression: {@var}
      """

      assert_raise(RuntimeError, message, fn ->
        assigns = %{var: 1}

        render_surface do
          ~F"""
          <MapProp prop={@var}/>
          """
        end
      end)
    end
  end

  describe "list" do
    test "passing a list" do
      html =
        render_surface do
          ~F"""
          <ListProp prop={[1, 2]}/>
          """
        end

      assert html =~ """
             List?: true
             <span>value: 1</span>\
             <span>value: 2</span>
             """
    end

    test "passing a list as an expression" do
      assigns = %{submit: [1, 2]}

      html =
        render_surface do
          ~F"""
          <ListProp prop={@submit}/>
          """
        end

      assert html =~ """
             List?: true
             <span>value: 1</span>\
             <span>value: 2</span>
             """
    end

    test "passing a list with a single value as an expression" do
      assigns = %{submit: [1]}

      html =
        render_surface do
          ~F"""
          <ListProp prop={@submit}/>
          """
        end

      assert html =~ """
             List?: true
             <span>value: 1</span>
             """
    end

    test "passing a list without brackets is invalid" do
      code =
        quote do
          ~F"""
          <ListProp prop={1, 2}/>
          """
        end

      message = ~S(code:1: invalid value for property "prop". Expected a :list, got: {1, 2}.)

      assert_raise(CompileError, message, fn ->
        compile_surface(code)
      end)
    end

    test "passing a list with a single value without brackets is invalid" do
      message = "invalid value for property \"prop\". Expected a :list, got: 1"

      assert_raise(RuntimeError, message, fn ->
        render_surface do
          ~F"""
          <ListProp prop={1}/>
          """
        end
      end)
    end

    test "passing a keyword list" do
      html =
        render_surface do
          ~F"""
          <ListProp prop={[a: 1, b: 2]}/>
          """
        end

      assert html =~ """
             List?: true
             <span>value: {:a, 1}</span><span>value: {:b, 2}</span>
             """
    end

    test "passing a range" do
      html =
        render_surface do
          ~F"""
          <ListProp prop={1..3}/>
          """
        end

      assert html =~ """
             List?: true
             <span>value: 1</span><span>value: 2</span><span>value: 3</span>
             """
    end

    test "passing a keyword list without brackets" do
      html =
        render_surface do
          ~F"""
          <ListProp prop={a: 1, b: 2}/>
          """
        end

      assert html =~ """
             List?: true
             <span>value: {:a, 1}</span><span>value: {:b, 2}</span>
             """
    end

    test "validate invalid literals at compile-time" do
      code =
        quote do
          ~F"""
          <ListProp prop="some string"/>
          """
        end

      message = ~S(code:1: invalid value for property "prop". Expected a :list, got: "some string".)

      assert_raise(CompileError, message, fn ->
        compile_surface(code)
      end)
    end

    test "validate invalid values at runtime" do
      message = "invalid value for property \"prop\". Expected a :list, got: %{test: 1}"

      assert_raise(RuntimeError, message, fn ->
        render_surface do
          ~F"""
          <ListProp prop={%{test: 1}}/>
          """
        end
      end)
    end
  end

  describe "css_class" do
    test "passing a string" do
      html =
        render_surface do
          ~F"""
          <CSSClassProp prop="class1 class2"/>
          """
        end

      assert html =~ """
             <span class="class1 class2"></span>
             """
    end

    test "passing a keywod list" do
      html =
        render_surface do
          ~F"""
          <CSSClassProp prop={[class1: true, class2: false, class3: "truthy"]}/>
          """
        end

      assert html =~ """
             <span class="class1 class3"></span>
             """
    end

    test "passing a keywod list without brackets" do
      html =
        render_surface do
          ~F"""
          <CSSClassProp prop={class1: true, class2: false, class3: "truthy"}/>
          """
        end

      assert html =~ """
             <span class="class1 class3"></span>
             """
    end

    test "trim class items" do
      html =
        render_surface do
          ~F"""
          <CSSClassProp prop={"", " class1 " , "", " ", "  ", " class2 class3 ", ""}/>
          """
        end

      assert html =~ """
             <span class="class1 class2 class3"></span>
             """
    end

    test "values are always converted to a list of strings" do
      html =
        render_surface do
          ~F"""
          <CSSClassPropInspect prop="class1 class2   class3"/>
          """
        end

      assert html =~ """
             <div>class1</div><div>class2</div><div>class3</div>
             """

      html =
        render_surface do
          ~F"""
          <CSSClassPropInspect prop={["class1"] ++ ["class2 class3", :class4, class5: true]}/>
          """
        end

      assert html =~ """
             <div>class1</div><div>class2</div><div>class3</div><div>class4</div><div>class5</div>
             """
    end
  end

  describe "accumulate" do
    test "if true, groups all props with the same name in a single list" do
      html =
        render_surface do
          ~F"""
          <AccumulateProp prop="str_1" prop={"str_2"}/>
          """
        end

      assert html =~ """
             List?: true
             <span>value: str_1</span>\
             <span>value: str_2</span>
             """
    end

    test "if true and there's a single prop, it stills creates a list" do
      html =
        render_surface do
          ~F"""
          <AccumulateProp prop="str_1"/>
          """
        end

      assert html =~ """
             List?: true
             <span>value: str_1</span>
             """
    end

    test "without any props, takes the default value" do
      html =
        render_surface do
          ~F"""
          <AccumulateProp/>
          """
        end

      assert html =~ """
             List?: true
             <span>value: default</span>
             """
    end
  end

  describe "root property" do
    test "component accepts root property" do
      assigns = %{label: "Label"}

      html =
        render_surface do
          ~F"""
          <RootProp {@label} />
          """
        end

      assert html =~ """
             Label
             """
    end
  end
end

defmodule Surface.PropertiesSyncTest do
  use Surface.ConnCase

  import ExUnit.CaptureIO
  alias Surface.PropertiesTest.StringProp, warn: false
  alias Surface.PropertiesTest.RootProp, warn: false

  test "warn if prop is required and has default value" do
    id = :erlang.unique_integer([:positive]) |> to_string()
    module = "TestComponentWithRequiredAndDefaultProp_#{id}"

    code = """
    defmodule #{module} do
      use Surface.Component

      prop label, :string, default: "My Label", required: true

      def render(assigns) do
        ~F""
      end
    end
    """

    output =
      capture_io(:standard_error, fn ->
        {{:module, _, _, _}, _} = Code.eval_string(code, [], %{__ENV__ | file: "code.exs", line: 1})
      end)

    assert output =~ ~r"""
           setting a default value on a required prop has no effect. Either set the default value or set the prop as required, but not both.
             code.exs:4:\
           """
  end

  test "warn if props are specified multiple times, but accumulate is false" do
    id = :erlang.unique_integer([:positive]) |> to_string()
    module = "TestComponentWithPropSpecifiedMultipleTimes_#{id}"

    code = """
    defmodule #{module} do
      use Surface.Component

      def render(assigns) do
        ~F"\""
        <StringProp
          label="first
          label" label="second label"
        />
        "\""
      end
    end
    """

    output =
      capture_io(:standard_error, fn ->
        {{:module, _, _, _}, _} = Code.eval_string(code, [], %{__ENV__ | file: "code.exs", line: 1})
      end)

    assert output =~ ~r"""
           the prop `label` has been passed multiple times. Considering only the last value.

           Hint: Either remove all redundant definitions or set option `accumulate` to `true`:

           ```
             prop label, :string, accumulate: true
           ```

           This way the values will be accumulated in a list.

             code.exs:8:\
           """
  end

  test "warn if attrs are specified multiple times for html tag" do
    id = :erlang.unique_integer([:positive]) |> to_string()
    module = "TestComponentWithAttrsSpecifiedMultipleTimes_#{id}"

    code = """
    defmodule #{module} do
      use Surface.Component

      def render(assigns) do
        ~F"\""
        <div
          class="foo"
          class="bar"
        />
        "\""
      end
    end
    """

    output =
      capture_io(:standard_error, fn ->
        {{:module, _, _, _}, _} = Code.eval_string(code, [], %{__ENV__ | file: "code.exs", line: 1})
      end)

    assert output =~ ~r"""
           the attribute `class` has been passed multiple times on line 6. \
           Considering only the last value.

           Hint: remove all redundant definitions

             code.exs:8:\
           """
  end

  test "warn if given default value doesn't exist in values list" do
    id = :erlang.unique_integer([:positive]) |> to_string()
    module = "TestComponentWithDefaultValueThatDoesntExistInValues_#{id}"

    code = """
    defmodule #{module} do
      use Surface.Component

      prop type, :string, values!: ["small", "medium", "large"], default: "x-large"

      data data_type, :string, values!: ["small", "medium", "large"], default: "x-large"

      prop invalid_type, :integer, default: [], values!: [0, 1, 2]

      prop valid_acc, :integer, default: [1], values!: [0, 1, 2], accumulate: true

      prop invalid_acc1, :integer, default: [3], values!: [0, 1, 2], accumulate: true

      prop invalid_acc2, :string, values!: [1, 2, 3], default: 3, accumulate: true

      def render(assigns) do
        ~F""
      end
    end
    """

    output =
      capture_io(:standard_error, fn ->
        {{:module, _, _, _}, _} = Code.eval_string(code, [], %{__ENV__ | file: "code.exs", line: 1})
      end)

    assert output =~ ~S"""
           prop `type` default value `"x-large"` does not exist in `:values!`
           """

    assert output =~ ~S"""
           data `data_type` default value `"x-large"` does not exist in `:values!`
           """

    assert output =~ ~S"""
           prop `invalid_type` default value `[]` does not exist in `:values!`
           """

    refute output =~ ~S"""
           prop `valid_acc`
           """

    assert output =~ ~S"""
           prop `invalid_acc1` default value `[3]` does not exist in `:values!`
           """

    assert output =~ ~S"""
           prop `invalid_acc2` default value `3` must be a list when `accumulate: true`
           """
  end

  test "warn if component does not accept a root property" do
    assigns = %{label: "root"}

    code =
      quote do
        ~F"""
        <StringProp
          {@label}
        />
        """
      end

    output =
      capture_io(:standard_error, fn ->
        compile_surface(code, assigns)
      end)

    assert output =~ ~r"""
           no root property defined for component <StringProp>

           Hint: you can declare a root property using option `root: true`

             code:2:\
           """
  end

  test "warn if tag has a root property and the property assigned normally" do
    assigns = %{label: "root"}

    code =
      quote do
        ~F"""
        <RootProp
          {@label}
          label="toor"
        />
        """
      end

    output =
      capture_io(:standard_error, fn ->
        compile_surface(code, assigns)
      end)

    assert output =~ ~r"""
           the prop `label` has been passed multiple times. Considering only the last value.

           Hint: Either specify the `label` via the root property \(`<RootProp { ... }>`\) or \
           explicitly via the label property \(`<RootProp label="...">`\), but not both.

             code:3:\
           """
  end

  test "error if the deprecation message is not set correctly" do
    code = """
        defmodule WrongDeprecatedPropComponent do
          use Surface.Component

          prop deprecated, :any, deprecated: true

          def render(assigns) do
            ~F"\""
            "\""
          end
        end
    """

    message = "code.exs:4: invalid value for option :deprecated in prop deprecated. Expected a string, got: true"

    assert_raise(CompileError, message, fn ->
      {{:module, _, _, _}, _} = Code.eval_string(code, [], %{__ENV__ | file: "code.exs", line: 1})
    end)
  end

  defmodule DeprecatedPropComponent do
    use Surface.Component

    prop deprecated, :any, deprecated: "This prop is deprecated"

    def render(assigns) do
      ~F"""
      """
    end
  end

  test "warn if deprecated prop is set on component" do
    code =
      quote do
        ~F"""
        <DeprecatedPropComponent deprecated="test" />
        """
      end

    output =
      capture_io(:standard_error, fn ->
        compile_surface(code, %{deprecated: "anst"})
      end)

    assert output =~ ~r"""
           the prop `deprecated` is marked as deprecated.
           Hint: This prop is deprecated

             code:1:\
           """
  end
end
