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

  defmodule PropsInspect do
    use Surface.Component

    prop class, :css_class
    prop event, :event

    def render(assigns) do
      ~F[{inspect(@class)} | {inspect(@event)}]
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

  defmodule RootGeneratorProp do
    use Surface.Component

    prop labels, :generator, root: true
    slot default, generator_prop: :labels

    def render(assigns) do
      ~F"""
      {#if is_nil(@labels)}
        No labels
      {#else}
        {#for label <- @labels}
          <#slot generator_value={label} />
        {/for}
      {/if}
      """
    end
  end

  test "translate props correctly inside vanilla function components' slots" do
    html =
      render_surface do
        ~F"""
        <PropsInspect class="h-full" event="click"/>
        <Phoenix.Component.link>
          <PropsInspect class="h-full" event="click"/>
        </Phoenix.Component.link>
        """
      end

    assert String.replace(html, "&quot;", ~S(")) =~ """
           ["h-full"] | %{name: "click", target: :live_view}
           <a href="#">
             ["h-full"] | %{name: "click", target: :live_view}
           </a>
           """
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

      message =
        ~r/code:1:\n#{maybe_ansi("error:")} invalid value for property "as"\. Expected a :atom, got: "some string"\./

      assert_raise(Surface.CompileError, message, fn ->
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

    test "passing a map" do
      html =
        render_surface do
          ~F"""
          <KeywordProp prop={%{option1: 1, option2: 2}}/>
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

      message =
        ~r/code:1:\n#{maybe_ansi("error:")} invalid value for property "prop"\. Expected a :keyword, got: "some string"\./

      assert_raise(Surface.CompileError, message, fn ->
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

    test "validate invalid values at runtime, Date" do
      message = """
      invalid value for property "prop". Expected a :keyword, got: ~D[2019-10-31].

      Original expression: {~D[2019-10-31]}
      """

      assert_raise(RuntimeError, message, fn ->
        render_surface do
          ~F"""
          <KeywordProp prop={~D[2019-10-31]} />
          """
        end
      end)
    end

    test "validate invalid values at runtime, range" do
      message = """
      invalid value for property "prop". Expected a :keyword, got: 1..3.

      Original expression: {1..3}
      """

      assert_raise(RuntimeError, message, fn ->
        render_surface do
          ~F"""
          <KeywordProp prop={1..3} />
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

      message =
        ~r/code:1:\n#{maybe_ansi("error:")} invalid value for property "prop"\. Expected a :map, got: "some string"\./

      assert_raise(Surface.CompileError, message, fn ->
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

      message =
        ~r/code:1:\n#{maybe_ansi("error:")} invalid value for property "prop"\. Expected a :list, got: {1, 2}\./

      assert_raise(Surface.CompileError, message, fn ->
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

      message =
        ~r/code:1:\n#{maybe_ansi("error:")} invalid value for property "prop"\. Expected a :list, got: "some string"\./

      assert_raise(Surface.CompileError, message, fn ->
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

    test "component accepts root generator property" do
      html =
        render_surface do
          ~F"""
          <RootGeneratorProp {label <- ["Label1", "Label2"]}>
            Slot: {label}
          </RootGeneratorProp>
          """
        end

      assert html =~ """
               Slot: Label1
               Slot: Label2
             """
    end

    test "component accepts root generator property with assign" do
      assigns = %{labels: ["Label1", "Label2"]}

      html =
        render_surface do
          ~F"""
          <RootGeneratorProp {label <- @labels}>
            Slot: {label}
          </RootGeneratorProp>
          """
        end

      assert html =~ """
               Slot: Label1
               Slot: Label2
             """
    end

    test "generator not given works" do
      html =
        render_surface do
          ~F"""
          <RootGeneratorProp>
            Slot
          </RootGeneratorProp>
          """
        end

      assert html =~ """
               No labels
             """
    end

    test "generator with invalid match without :let" do
      message = """
      cannot match generator value against generator binding. Expected a value matching `[label]`, got: "Label1".\
      """

      assert_raise_with_line(ArgumentError, message, 4, fn ->
        render_surface do
          ~F"""
          <RootGeneratorProp
            {[label] <- ["Label1", "Label2"]}>
            Slot: {label}
          </RootGeneratorProp>
          """
        end
      end)
    end

    test "validate invalid values at runtime" do
      message = """
      invalid value for property "label". Expected a :string, got: ["label", "label2"].

      Original expression: {"label",  "label2"}
      """

      assert_raise(RuntimeError, message, fn ->
        render_surface do
          ~F"""
          <RootProp {"label",  "label2"} />
          """
        end
      end)
    end

    test "validate if not generator at compile time" do
      code =
        quote do
          ~F"""
          <RootGeneratorProp
            {"label"} />
          """
        end

      message = ~r"""
      code:2:
      #{maybe_ansi("error:")} invalid value for property "labels"\. Expected a :generator Example: `{i <- \.\.\.}`, got: {"label"}\.\
      """

      assert_raise(Surface.CompileError, message, fn ->
        compile_surface(code)
      end)
    end
  end
end

defmodule Surface.PropertiesSyncTest do
  use Surface.ConnCase

  import ExUnit.CaptureIO
  alias Surface.PropertiesTest.StringProp
  alias Surface.PropertiesTest.ListProp

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

  test "warn if generator_value property is missing" do
    id = :erlang.unique_integer([:positive]) |> to_string()
    module = "TestComponentWithDefaultValueThatDoesntExistInValues_#{id}"

    code = """
    defmodule #{module} do
      use Surface.Component

      prop labels, :generator, root: true
      slot default, generator_prop: :labels

      def render(assigns) do
        ~F"\""
        {#for label <- @labels}
          {label}
          <#slot />
        {/for}
        "\""
      end
    end
    """

    message = ~r"code.exs:11:\n#{maybe_ansi("error:")} `generator_value` is missing for slot `default`"

    assert_raise(Surface.CompileError, message, fn ->
      {{:module, _, _, _}, _} = Code.eval_string(code, [], %{__ENV__ | file: "code.exs", line: 1})
    end)
  end

  defmodule AccumulateListProp do
    use Surface.Component

    prop prop, :list, accumulate: true, default: [[1, 2, 3]]

    def render(assigns) do
      ~F"""
      List?: {is_list(@prop)}
      <span :for={v <- @prop}>value: {inspect(v)}</span>
      """
    end
  end

  describe "accumulate with list prop" do
    test "if true, groups all props with the same name in a single list" do
      html =
        render_surface do
          ~F"""
          <AccumulateListProp prop={[1, 2]} prop={[3, 4]} />
          """
        end

      assert html =~ """
             List?: true
             <span>value: [1, 2]</span>\
             <span>value: [3, 4]</span>
             """
    end

    test "if true and there's a single prop, it stills creates a list" do
      html =
        render_surface do
          ~F"""
          <AccumulateListProp prop={[1, 2]} />
          """
        end

      assert html =~ """
             List?: true
             <span>value: [1, 2]</span>
             """
    end

    test "without any props, takes the default value" do
      html =
        render_surface do
          ~F"""
          <AccumulateListProp />
          """
        end

      assert html =~ """
             List?: true
             <span>value: [1, 2, 3]</span>
             """
    end

    test "if not true renders only the last value" do
      output =
        capture_io(:standard_error, fn ->
          html =
            render_surface do
              ~F"""
              <StringProp label="label 1" label="label 2" />
              """
            end

          assert html =~ """
                 label 2
                 """
        end)

      assert output =~ """
             the prop `label` has been passed multiple times. Considering only the last value.

             Hint: Either remove all redundant definitions or set option `accumulate` to `true`:

             ```
               prop label, :string, accumulate: true
             ```

             This way the values will be accumulated in a list.
             """
    end

    test "if not true renders only the last value, list prop" do
      output =
        capture_io(:standard_error, fn ->
          html =
            render_surface do
              ~F"""
              <ListProp prop={[1, 2]} prop={[3, 4]}/>
              """
            end

          assert html =~ """
                 List?: true
                 <span>value: 3</span>\
                 <span>value: 4</span>
                 """
        end)

      assert output =~ """
             the prop `prop` has been passed multiple times. Considering only the last value.

             Hint: Either remove all redundant definitions or set option `accumulate` to `true`:

             ```
               prop prop, :list, accumulate: true
             ```

             This way the values will be accumulated in a list.
             """
    end

    test "if not true renders only the last value, dynamic attributes" do
      output =
        capture_io(:standard_error, fn ->
          html =
            render_surface do
              ~F"""
              <ListProp {...[prop: [1, 2], prop: [3, 4]]}/>
              """
            end

          assert html =~ """
                 List?: true
                 <span>value: 3</span>\
                 <span>value: 4</span>
                 """
        end)

      assert output =~ """
             the prop `prop` has been passed multiple times. Considering only the last value.

             Hint: Either remove all redundant definitions or set option `accumulate` to `true`:

             ```
               prop prop, :list, accumulate: true
             ```

             This way the values will be accumulated in a list.
             """
    end

    test "warns without root prop" do
      output =
        capture_io(:standard_error, fn ->
          html =
            render_surface do
              ~F"""
              <StringProp {"root label"} />
              """
            end

          assert html =~ """
                 """
        end)

      assert output =~ """
             no root property defined for component <StringProp>

             Hint: you can declare a root property using option `root: true`
             """
    end

    test "literal expression to list prop don't emit warnings" do
      code =
        quote do
          ~F"""
          <ListProp prop={1}/>
          """
        end

      output = capture_io(:standard_error, fn -> compile_surface(code) end)

      refute output =~ """
             this check/guard will always yield the same result
               code
             """

      assert output == ""
    end
  end
end
