defmodule Surface.APITest do
  use Surface.Case, async: true

  test "raise error at the right line" do
    code = "prop label, :unknown_type"
    message = ~r/code:4/

    assert_raise(Surface.CompileError, message, fn -> eval(code) end)
  end

  test "validate ast type" do
    code = "prop label, {:a, :b}"

    message = ~r"""
    invalid type for prop label. \
    Expected an atom, got: {:a, :b}
    """

    assert_raise(Surface.CompileError, message, fn -> eval(code) end)
  end

  test "validate type in list of available types" do
    code = "prop label, :foo"
    message = ~r/invalid type :foo for prop label.\nExpected one of \[:any/

    assert_raise(Surface.CompileError, message, fn -> eval(code) end)
  end

  test "validate options" do
    code = "prop label, :string, {:a, :b}"

    message = ~r/invalid options for prop label. Expected a keyword list of options, got: {:a, :b}/

    assert_raise(Surface.CompileError, message, fn -> eval(code) end)
  end

  test "validate type options" do
    code = "data label, :string, a: 1"
    message = ~r/unknown option :a/

    assert_raise(Surface.CompileError, message, fn -> eval(code) end)

    code = "data label, :string, a: 1, b: 2"
    message = ~r/unknown options \[:a, :b\]/

    assert_raise(Surface.CompileError, message, fn -> eval(code) end)
  end

  test "validate :required" do
    code = "prop label, :string, required: 1"
    message = ~r/invalid value for option :required. Expected a boolean, got: 1/

    assert_raise(Surface.CompileError, message, fn -> eval(code) end)
  end

  test "validate :values" do
    code = "prop label, :string, values: 1"
    message = ~r/invalid value for option :values. Expected a list of values or a Range, got: 1/

    assert_raise(Surface.CompileError, message, fn -> eval(code) end)
  end

  test "validate :values when using a range" do
    code = """
    prop age, :integer, values: 1..100
    data items, :integer, values: 1..3
    """

    {:ok, _module} = eval(code)
  end

  test "validate :as in slot" do
    code = "slot label, as: \"default_label\""
    message = ~r/invalid value for option :as in slot. Expected an atom, got: \"default_label\"/

    assert_raise(Surface.CompileError, message, fn -> eval(code) end)
  end

  test "validate :root in prop" do
    code = "prop label, :string, root: 1"
    message = ~r/invalid value for option :root. Expected a boolean, got: 1/

    assert_raise(Surface.CompileError, message, fn -> eval(code) end)
  end

  test "validate :static in prop" do
    code = "prop label, :string, static: 1"
    message = ~r/invalid value for option :static. Expected a boolean, got: 1/

    assert_raise(Surface.CompileError, message, fn -> eval(code) end)
  end

  test "validate :from_context type" do
    message = ~r"""
    invalid value for option :from_context.

    Expected: a `key when is_atom\(key\)` or a tuple `{scope, key} when is_atom\(scope\) and is_atom\(key\)`.

    Got: 123
    """

    code = "prop field, :any, from_context: 123"
    assert_raise(Surface.CompileError, message, fn -> eval(code) end)

    code = "data field, :any, from_context: 123"
    assert_raise(Surface.CompileError, message, fn -> eval(code) end)
  end

  test "validate :from_context with :default" do
    message = ~r/using option :from_context along with :default is currently not allowed/

    code = "prop field, :any, from_context: :field, default: :my_field"
    assert_raise(Surface.CompileError, message, fn -> eval(code) end)

    code = "data field, :any, from_context: :field, default: :my_field"
    assert_raise(Surface.CompileError, message, fn -> eval(code) end)
  end

  test "validate :from_context in LiveView" do
    message = ~r/option :from_context is not supported for Surface.Liveview/

    code = "prop field, :any, from_context: :field"
    assert_raise(Surface.CompileError, message, fn -> eval(code, "LiveView") end)

    code = "data field, :any, from_context: :field"
    assert_raise(Surface.CompileError, message, fn -> eval(code, "LiveView") end)
  end

  test "validate :css_variant type + options" do
    # type :boolean
    code = "prop field, :boolean, css_variant: true"
    assert {:ok, _} = eval(code)

    # type :list
    code = "prop field, :list, css_variant: true"
    assert {:ok, _} = eval(code)

    # other types with :values
    code = "prop field, :string, values: [:a, :b], css_variant: true"
    assert {:ok, _} = eval(code)

    # other types with :values!
    code = "prop field, :string, values!: [:a, :b], css_variant: true"
    assert {:ok, _} = eval(code)

    # invalid value
    code = "prop field, :string, css_variant: 123"

    message = ~r"""
    code:4:
    #{maybe_ansi("error:")} invalid value for :css_variant\. Expected either a boolean or a keyword list of options, got: 123\.

    Valid options for type :string are:

      \* :not_nil - the name of the variant when the value is not `nil`\. Default is the assign name\.
      \* :nil - the name of the variant when the value is `nil`\. Default is `no-\[assign-name\]`\.

    or, if you use the `values` or `values!` options:

      \* :prefix - the prefix of the variant name for each value listed in `values` or `values!`. Default is `\[assign-name\]-`\.
    """

    assert_raise(Surface.CompileError, message, fn -> eval(code) end)
  end

  test "validate duplicate assigns" do
    code = """
    prop label, :string
    prop label, :string
    """

    message = ~r"""
    cannot use name "label". \
    There's already a prop assign with the same name at line 4\
    """

    assert_raise(Surface.CompileError, message, fn -> eval(code) end)

    code = """
    prop label, :string
    data label, :string
    """

    message = ~r/cannot use name "label". There's already a prop/
    assert_raise(Surface.CompileError, message, fn -> eval(code) end)

    code = """
    prop label, :string
    slot label
    """

    message = ~r/cannot use name "label". There's already a prop/
    assert_raise(Surface.CompileError, message, fn -> eval(code) end)

    code = """
    data label, :string
    data label, :string
    """

    message = ~r/cannot use name "label". There's already a data assign/
    assert_raise(Surface.CompileError, message, fn -> eval(code) end)

    code = """
    data label, :string
    prop label, :string
    """

    message = ~r/cannot use name "label". There's already a data assign/
    assert_raise(Surface.CompileError, message, fn -> eval(code) end)

    code = """
    data label, :string
    slot label
    """

    message = ~r/cannot use name "label". There's already a data assign/
    assert_raise(Surface.CompileError, message, fn -> eval(code) end)

    code = """
    slot label
    slot label
    """

    message = ~r"""
    cannot use name "label". There's already a slot assign with the same name at line \d.
    You could use the optional ':as' option in slot macro to name the related assigns.
    """

    assert_raise(Surface.CompileError, message, fn -> eval(code) end)

    code = """
    slot label
    data label, :string
    """

    message = ~r"""
    cannot use name "label". There's already a slot assign with the same name at line \d.
    You could use the optional ':as' option in slot macro to name the related assigns.
    """

    assert_raise(Surface.CompileError, message, fn -> eval(code) end)

    code = """
    slot label
    prop label, :string
    """

    message = ~r"""
    cannot use name "label". There's already a slot assign with the same name at line \d.
    You could use the optional ':as' option in slot macro to name the related assigns.
    """

    assert_raise(Surface.CompileError, message, fn -> eval(code) end)

    code = """
    slot label, as: :default_label
    prop label, :string
    """

    assert {:ok, _} = eval(code)

    code = """
    prop label, :string
    slot label, as: :default_label
    """

    assert {:ok, _} = eval(code)

    code = """
    data label, :string
    slot label, as: :default_label
    """

    assert {:ok, _} = eval(code)

    code = """
    slot label, as: :default_label
    data label, :string
    """

    assert {:ok, _} = eval(code)
  end

  test "validate duplicate built-in assigns for Component" do
    code = """
    data socket, :any
    """

    message = ~r"""
    cannot use name "socket". \
    There's already a built-in data assign with the same name.\
    """

    assert_raise(Surface.CompileError, message, fn -> eval(code, "LiveComponent") end)

    # Ignore built-in assigns from other component types
    code = """
    data socket, :any  # LiveComponent
    data myself, :any  # LiveComponent
    data uploads, :any # LiveView
    """

    {:ok, _module} = eval(code, "Component")
  end

  test "validate duplicate built-in assigns for LiveComponent" do
    code = """
    data myself, :any
    """

    message = ~r"""
    cannot use name "myself". \
    There's already a built-in data assign with the same name.\
    """

    assert_raise(Surface.CompileError, message, fn -> eval(code, "LiveComponent") end)

    # Ignore built-in assigns from other component types
    code = """
    data inner_block, :any  # Component
    data uploads, :string   # LiveView
    """

    {:ok, _module} = eval(code, "LiveComponent")
  end

  test "validate duplicate built-in assigns for LiveView" do
    code = """
    data uploads, :any
    """

    message = ~r"""
    cannot use name "uploads". \
    There's already a built-in data assign with the same name.\
    """

    assert_raise(Surface.CompileError, message, fn -> eval(code, "LiveView") end)

    # Ignore built-in assigns from other component types
    code = """
    data inner_block, :any  # Component
    data myself, :any       # LiveComponent
    """

    {:ok, _module} = eval(code, "LiveView")
  end

  test "raise compile error for component with multiple root properties" do
    code = """
    prop title, :string, root: true
    prop label, :string, root: true
    """

    message = ~r"""
    cannot define multiple properties as `root: true`. \
    Property `title` at line 4 was already defined as root.

    Hint: choose a single property to be the root prop.
    """

    assert_raise(Surface.CompileError, message, fn -> eval(code) end)
  end

  test "accept invalid quoted expressions like literal maps as default value" do
    code = """
    prop map, :map, default: %{a: 1, b: 2}
    """

    assert {:ok, module} = eval(code)
    assert module.__get_prop__(:map)[:opts][:default] == %{a: 1, b: 2}
  end

  test "accept module attributes as default value" do
    code = """
    @default_map %{a: 1, b: 2}
    data my_map, :map, default: @default_map
    """

    assert {:ok, module} = eval(code)
    [data | _] = module.__data__()
    assert data[:name] == :my_map
    assert data[:opts][:default] == %{a: 1, b: 2}
  end

  describe "property" do
    test "validate name" do
      code = "prop {a, b}, :string"
      message = ~r/invalid prop name. Expected a variable name, got: {a, b}/

      assert_raise(Surface.CompileError, message, fn ->
        eval(code)
      end)
    end

    test "common type options" do
      code = "prop count, :integer, required: false, default: [], values: [0, 1, 2], accumulate: true"

      assert {:ok, _} = eval(code)
    end

    test "validate unknown type options" do
      code = "prop label, :string, a: 1"

      message =
        ~r/unknown option :a. Available options: \[:required, :default, :values, :values!, :accumulate, :root, :static, :from_context, :css_variant\]/

      assert_raise(Surface.CompileError, message, fn ->
        eval(code)
      end)
    end
  end

  describe "slot" do
    test "validate name" do
      code = "slot {a, b}"
      message = ~r/invalid slot name. Expected a variable name, got: {a, b}/

      assert_raise(Surface.CompileError, message, fn ->
        eval(code)
      end)
    end

    test "validate unknown options" do
      code = "slot cols, a: 1"
      message = ~r/unknown option :a. Available options: \[:required, :arg, :as, :generator_prop\]/

      assert_raise(Surface.CompileError, message, fn ->
        eval(code)
      end)
    end

    test "raise compile error when a slot arg is bound to a non-existing property" do
      id = :erlang.unique_integer([:positive]) |> to_string()
      module = "TestSlotWithoutSlotName_#{id}"

      code = """
      defmodule #{module} do
        use Surface.Component

        prop label, :string
        prop items, :generator

        slot default, generator_prop: :unknown

        def render(assigns), do: ~F()
      end
      """

      message = ~r"""
      code.exs:7:
      #{maybe_ansi("error:")} cannot use property `unknown` as generator for slot\. \
      Expected an existing property of type `:generator`, got: an undefined property `unknown`.

      Hint: Available generators are \[:items\]\
      """

      assert_raise(Surface.CompileError, message, fn ->
        {{:module, _, _, _}, _} = Code.eval_string(code, [], %{__ENV__ | file: "code.exs", line: 1})
      end)
    end

    test "raise compile error when a slot arg is bound to a property of type other than :list" do
      id = :erlang.unique_integer([:positive]) |> to_string()
      module = "TestSlotWithoutSlotName_#{id}"

      code = """
      defmodule #{module} do
        use Surface.Component

        prop label, :string

        slot default, generator_prop: :label

        def render(assigns), do: ~F()
      end
      """

      message = ~r"""
      code.exs:6:
      #{maybe_ansi("error:")} cannot use property `label` as generator for slot\. \
      Expected a property of type :generator, got: a property of type :string

      Hint: Available generators are \[\]\
      """

      assert_raise(Surface.CompileError, message, fn ->
        {{:module, _, _, _}, _} = Code.eval_string(code, [], %{__ENV__ | file: "code.exs", line: 1})
      end)
    end
  end

  describe "data" do
    test "validate name" do
      code = "data {a, b}, :string"
      message = ~r/invalid data name. Expected a variable name, got: {a, b}/

      assert_raise(Surface.CompileError, message, fn ->
        eval(code)
      end)
    end

    test "common type options" do
      code = "data count, :integer, default: 0, values: [0, 1, 2]"
      assert {:ok, _} = eval(code)
    end

    test "validate unknown type options" do
      code = "data label, :string, a: 1"

      message =
        ~r/unknown option :a. Available options: \[:default, :values, :values!, :from_context, :css_variant\]/

      assert_raise(Surface.CompileError, message, fn ->
        eval(code)
      end)
    end
  end

  test "props are sorted semanticaly" do
    props = [
      %{
        line: 3,
        name: :header,
        opts: [required: true]
      },
      %{
        line: 2,
        name: :id,
        opts: [required: true]
      },
      %{
        line: 1,
        name: :footer,
        opts: []
      },
      %{
        line: 4,
        name: :body,
        opts: [required: true]
      }
    ]

    sorted_props = Surface.API.sort_props(props)

    assert [:id, :header, :body, :footer] = Enum.map(sorted_props, & &1.name)
  end

  test "generate documentation when no @moduledoc is defined" do
    assert get_docs(Surface.PropertiesTest.Components.MyComponent) == """
           ## Properties

           * **label** *:string, required: true* - The label
           * **class** *:css_class* - The class

           ## Slots

           * **default** - The default slot
           * **header, required: true** - The required header slot

           ## Events

           * **click, required: true** - The click event
           * **cancel** - The cancel event
           """
  end

  test "append properties' documentation when @moduledoc is defined" do
    assert get_docs(Surface.PropertiesTest.Components.MyComponentWithModuledoc) == """
           My component with @moduledoc

           ## Properties

           * **label** *:string, required: true* - The label
           * **class** *:css_class* - The class

           ## Slots

           * **default** - The default slot
           * **header, required: true** - The required header slot

           ## Events

           * **click, required: true** - The click event
           * **cancel** - The cancel event
           """
  end

  test "do not generate documentation when @moduledoc is false" do
    assert get_docs(Surface.PropertiesTest.Components.MyComponentWithModuledocFalse) == nil
  end

  test "do not generate documentation sections when there is no props, slots or event" do
    assert get_docs(Surface.PropertiesTest.Components.MyComponentWithDocButPropSlotAndEvent) ==
             """
             My Component with doc but props, slots and events
             """
  end

  defp eval(code, component_type \\ "LiveComponent") do
    id = :erlang.unique_integer([:positive]) |> to_string()
    module_name = "TestLiveComponent_#{id}"

    comp_code = """
    defmodule #{module_name} do
      use Surface.#{component_type}

      #{code}

      def render(assigns) do
        ~F(<div></div>)
      end
    end
    """

    {{:module, module, _, _}, _} = Code.eval_string(comp_code, [], file: "code")
    {:ok, module}
  end

  defp get_docs(module) do
    case Code.fetch_docs(module) do
      {:docs_v1, _, _, "text/markdown", %{"en" => docs}, %{}, _} ->
        docs

      _ ->
        nil
    end
  end
end

defmodule Surface.APISyncTest do
  use Surface.Case
  import ExUnit.CaptureIO

  defmodule ComponentWithRequiredDefaultSlot do
    use Surface.Component

    slot default, required: true
    slot header
    slot footer

    def render(assigns) do
      ~F"""
      <div>
        <#slot {@header}/>
        <#slot/>
        <#slot {@footer}/>
      </div>
      """
    end
  end

  defmodule ComponentWithRequiredSlots do
    use Surface.Component

    slot default
    slot header, required: true
    slot footer

    def render(assigns) do
      ~F"""
      <div>
        <#slot {@header}/>
        <#slot/>
        <#slot {@footer}/>
      </div>
      """
    end
  end

  describe "slot error/warnings" do
    test "warn if required default slot is not assigned (self-closed)" do
      id = :erlang.unique_integer([:positive]) |> to_string()
      module = "TestComponentWithRequiredDefaultSlot_#{id}"

      code = """
      defmodule #{module} do
        use Surface.Component

        def render(assigns) do
          ~F"\""
          <ComponentWithRequiredDefaultSlot/>
          "\""
        end
      end
      """

      output =
        capture_io(:standard_error, fn ->
          {{:module, _, _, _}, _} = Code.eval_string(code, [], %{__ENV__ | file: "code.exs", line: 1})
        end)

      assert output =~ ~S(missing required slot "default" for component <ComponentWithRequiredDefaultSlot>)
      assert output =~ "code.exs:6:"
    end

    test "warn if required slot is not assigned (blank content)" do
      id = :erlang.unique_integer([:positive]) |> to_string()
      module = "TestComponentWithRequiredDefaultSlot_#{id}"

      code = """
      defmodule #{module} do
        use Surface.Component

        def render(assigns) do
          ~F"\""
          <ComponentWithRequiredDefaultSlot>
          </ComponentWithRequiredDefaultSlot>
          "\""
        end
      end
      """

      output =
        capture_io(:standard_error, fn ->
          {{:module, _, _, _}, _} = Code.eval_string(code, [], %{__ENV__ | file: "code.exs", line: 1})
        end)

      assert output =~ ~S(missing required slot "default" for component <ComponentWithRequiredDefaultSlot>)
      assert output =~ "code.exs:6:"
    end

    test "warn if required default slot is not assigned (other slots present)" do
      id = :erlang.unique_integer([:positive]) |> to_string()
      module = "TestComponentWithRequiredDefaultSlot_#{id}"

      code = """
      defmodule #{module} do
        use Surface.Component

        def render(assigns) do
          ~F"\""
          <ComponentWithRequiredDefaultSlot>
            <:header>
              Header
            </:header>
          </ComponentWithRequiredDefaultSlot>
          "\""
        end
      end
      """

      output =
        capture_io(:standard_error, fn ->
          {{:module, _, _, _}, _} = Code.eval_string(code, [], %{__ENV__ | file: "code.exs", line: 1})
        end)

      assert output =~ ~S(missing required slot "default" for component <ComponentWithRequiredDefaultSlot>)
      assert output =~ "code.exs:6:"
    end

    test "warn if a required named slot is not assigned" do
      id = :erlang.unique_integer([:positive]) |> to_string()
      module = "TestComponentWithRequiredSlots_#{id}"

      code = """
      defmodule #{module} do
        use Surface.Component

        def render(assigns) do
          ~F"\""
          <ComponentWithRequiredSlots>
          </ComponentWithRequiredSlots>
          "\""
        end
      end
      """

      output =
        capture_io(:standard_error, fn ->
          {{:module, _, _, _}, _} = Code.eval_string(code, [], %{__ENV__ | file: "code.exs", line: 1})
        end)

      assert output =~ ~S(missing required slot "header" for component <ComponentWithRequiredSlots>)
      assert output =~ "code.exs:6:"
    end

    if Version.match?(System.version(), ">= 1.15.0") do
      test "do not validate required slots of non-existing components" do
        id = :erlang.unique_integer([:positive]) |> to_string()
        module = "TestComponentWithRequiredDefaultSlot_#{id}"

        code = """
        defmodule #{module} do
          use Surface.Component

          def render(assigns) do
            ~F"\""
            <ComponentWithRequiredDefaultSlot>
              <NonExisting>
                Don't validate me!
              </NonExisting>
            </ComponentWithRequiredDefaultSlot>
            "\""
          end
        end
        """

        diagnostics =
          Code.with_diagnostics(fn ->
            try do
              Code.eval_string(code, [], %{__ENV__ | file: "code.exs", line: 1})
            rescue
              e -> e
            end
          end)

        assert {%Surface.CompileError{
                  description: "cannot render <NonExisting> (module NonExisting could not be loaded)",
                  hint: """
                  make sure module `NonExisting` can be successfully compiled.

                  If the module is namespaced, you can use its full name. For instance:

                    <MyProject.Components.NonExisting>

                  or add a proper alias so you can use just `<NonExisting>`:

                    alias MyProject.Components.NonExisting
                  """,
                  file: "code.exs",
                  line: 7,
                  column: 8
                }, []} = diagnostics
      end
    else
      # Remove this test (and the `if`) whenever we drop support for Elixir < 1.15
      test "do not validate required slots of non-existing components" do
        id = :erlang.unique_integer([:positive]) |> to_string()
        module = "TestComponentWithRequiredDefaultSlot_#{id}"

        code = """
        defmodule #{module} do
          use Surface.Component

          def render(assigns) do
            ~F"\""
            <ComponentWithRequiredDefaultSlot>
              <NonExisting>
                Don't validate me!
              </NonExisting>
            </ComponentWithRequiredDefaultSlot>
            "\""
          end
        end
        """

        error_message =
          ~r"code.exs:7(:8)?:\n#{maybe_ansi("error:")} cannot render <NonExisting> \(module NonExisting could not be loaded\)"

        assert_raise(Surface.CompileError, error_message, fn ->
          {{:module, _, _, _}, _} =
            Code.eval_string(code, [], %{__ENV__ | file: "code.exs", line: 1}) |> IO.inspect()
        end)
      end
    end
  end
end
