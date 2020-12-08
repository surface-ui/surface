defmodule Surface.APITest do
  use ExUnit.Case, async: true

  test "raise error at the right line" do
    code = "prop label, :unknown_type"
    message = ~r/code:4/

    assert_raise(CompileError, message, fn -> eval(code) end)
  end

  test "validate type" do
    code = "prop label, {:a, :b}"
    message = ~r/invalid type {:a, :b} for prop label.\nExpected one of \[:any/

    assert_raise(CompileError, message, fn -> eval(code) end)
  end

  test "validate options" do
    code = "prop label, :string, {:a, :b}"

    message =
      ~r/invalid options for prop label. Expected a keyword list of options, got: {:a, :b}/

    assert_raise(CompileError, message, fn -> eval(code) end)
  end

  test "validate type options" do
    code = "data label, :string, a: 1"
    message = ~r/unknown option :a/

    assert_raise(CompileError, message, fn -> eval(code) end)

    code = "data label, :string, a: 1, b: 2"
    message = ~r/unknown options \[:a, :b\]/

    assert_raise(CompileError, message, fn -> eval(code) end)
  end

  test "validate :required" do
    code = "prop label, :string, required: 1"
    message = ~r/invalid value for option :required. Expected a boolean, got: 1/

    assert_raise(CompileError, message, fn -> eval(code) end)
  end

  test "validate :values" do
    code = "prop label, :string, values: 1"
    message = ~r/invalid value for option :values. Expected a list of values, got: 1/

    assert_raise(CompileError, message, fn -> eval(code) end)
  end

  test "validate :as in slot" do
    code = "slot label, as: \"default_label\""
    message = ~r/invalid value for option :as in slot. Expected an atom, got: \"default_label\"/

    assert_raise(CompileError, message, fn -> eval(code) end)
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

    assert_raise(CompileError, message, fn -> eval(code) end)

    code = """
    prop label, :string
    data label, :string
    """

    message = ~r/cannot use name "label". There's already a prop/
    assert_raise(CompileError, message, fn -> eval(code) end)

    code = """
    prop label, :string
    slot label
    """

    message = ~r/cannot use name "label". There's already a prop/
    assert_raise(CompileError, message, fn -> eval(code) end)

    code = """
    data label, :string
    data label, :string
    """

    message = ~r/cannot use name "label". There's already a data assign/
    assert_raise(CompileError, message, fn -> eval(code) end)

    code = """
    data label, :string
    prop label, :string
    """

    message = ~r/cannot use name "label". There's already a data assign/
    assert_raise(CompileError, message, fn -> eval(code) end)

    code = """
    data label, :string
    slot label
    """

    message = ~r/cannot use name "label". There's already a data assign/
    assert_raise(CompileError, message, fn -> eval(code) end)

    code = """
    slot label
    slot label
    """

    message = ~r"""
    cannot use name "label". There's already a slot assign with the same name at line \d.
    You could use the optional ':as' option in slot macro to name the related assigns.
    """

    assert_raise(CompileError, message, fn -> eval(code) end)

    code = """
    slot label
    data label, :string
    """

    message = ~r"""
    cannot use name "label". There's already a slot assign with the same name at line \d.
    You could use the optional ':as' option in slot macro to name the related assigns.
    """

    assert_raise(CompileError, message, fn -> eval(code) end)

    code = """
    slot label
    prop label, :string
    """

    message = ~r"""
    cannot use name "label". There's already a slot assign with the same name at line \d.
    You could use the optional ':as' option in slot macro to name the related assigns.
    """

    assert_raise(CompileError, message, fn -> eval(code) end)

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

    assert_raise(CompileError, message, fn -> eval(code, "Component") end)

    # Ignore built-in assigns from other component types
    code = """
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

    assert_raise(CompileError, message, fn -> eval(code, "LiveComponent") end)

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

    assert_raise(CompileError, message, fn -> eval(code, "LiveView") end)

    # Ignore built-in assigns from other component types
    code = """
    data inner_block, :any  # Component
    data myself, :any       # LiveComponent
    """

    {:ok, _module} = eval(code, "LiveView")
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

      assert_raise(CompileError, message, fn ->
        eval(code)
      end)
    end

    test "common type options" do
      code =
        "prop count, :integer, required: false, default: [], values: [0, 1, 2], accumulate: true"

      assert {:ok, _} = eval(code)
    end

    test "validate unknown type options" do
      code = "prop label, :string, a: 1"

      message =
        ~r/unknown option :a. Available options: \[:required, :default, :values, :accumulate\]/

      assert_raise(CompileError, message, fn ->
        eval(code)
      end)
    end
  end

  describe "slot" do
    test "validate name" do
      code = "slot {a, b}"
      message = ~r/invalid slot name. Expected a variable name, got: {a, b}/

      assert_raise(CompileError, message, fn ->
        eval(code)
      end)
    end

    test "validate slot props" do
      code = "slot cols, props: [:info, {a, b}]"

      message = ~r"""
      invalid slot prop {a, b}. Expected an atom or a \
      binding to a generator as `key: \^property_name`\
      """

      assert_raise(CompileError, message, fn ->
        eval(code)
      end)
    end

    test "validate unknown options" do
      code = "slot cols, a: 1"
      message = ~r/unknown option :a. Available options: \[:required, :props, :as\]/

      assert_raise(CompileError, message, fn ->
        eval(code)
      end)
    end

    test "raise compile error when a slot prop is bound to a non-existing property" do
      id = :erlang.unique_integer([:positive]) |> to_string()
      module = "TestSlotWithoutSlotName_#{id}"

      code = """
      defmodule #{module} do
        use Surface.Component

        prop label, :string
        prop items, :list

        slot default, props: [item: ^unknown]

        def render(assigns), do: ~H()
      end
      """

      message = """
      code.exs:7: cannot bind slot prop `item` to property `unknown`. \
      Expected a existing property after `^`, got: an undefined property `unknown`.

      Hint: Available properties are [:label, :items]\
      """

      assert_raise(CompileError, message, fn ->
        {{:module, _, _, _}, _} =
          Code.eval_string(code, [], %{__ENV__ | file: "code.exs", line: 1})
      end)
    end

    test "raise compile error when a slot prop is bound to a property of type other than :list" do
      id = :erlang.unique_integer([:positive]) |> to_string()
      module = "TestSlotWithoutSlotName_#{id}"

      code = """
      defmodule #{module} do
        use Surface.Component

        prop label, :string

        slot default, props: [item: ^label]

        def render(assigns), do: ~H()
      end
      """

      message = """
      code.exs:6: cannot bind slot prop `item` to property `label`. \
      Expected a property of type :list after `^`, got: a property of type :string\
      """

      assert_raise(CompileError, message, fn ->
        {{:module, _, _, _}, _} =
          Code.eval_string(code, [], %{__ENV__ | file: "code.exs", line: 1})
      end)
    end
  end

  describe "data" do
    test "validate name" do
      code = "data {a, b}, :string"
      message = ~r/invalid data name. Expected a variable name, got: {a, b}/

      assert_raise(CompileError, message, fn ->
        eval(code)
      end)
    end

    test "common type options" do
      code = "data count, :integer, default: 0, values: [0, 1, 2]"
      assert {:ok, _} = eval(code)
    end

    test "validate unknown type options" do
      code = "data label, :string, a: 1"
      message = ~r/unknown option :a. Available options: \[:default, :values\]/

      assert_raise(CompileError, message, fn ->
        eval(code)
      end)
    end
  end

  test "generate documentation when no @moduledoc is defined" do
    assert get_docs(Surface.PropertiesTest.Components.MyComponent) == """
           ### Properties

           * **label** *:string, required: true, default: ""* - The label.
           * **class** *:css_class* - The class.
           """
  end

  test "append properties' documentation when @moduledoc is defined" do
    assert get_docs(Surface.PropertiesTest.Components.MyComponentWithModuledoc) == """
           My component with @moduledoc

           ### Properties

           * **label** *:string, required: true, default: ""* - The label.
           * **class** *:css_class* - The class.
           """
  end

  test "do not generate documentation when @moduledoc is false" do
    assert get_docs(Surface.PropertiesTest.Components.MyComponentWithModuledocFalse) == nil
  end

  defp eval(code, component_type \\ "LiveComponent") do
    id = :erlang.unique_integer([:positive]) |> to_string()
    module_name = "TestLiveComponent_#{id}"

    comp_code = """
    defmodule #{module_name} do
      use Surface.#{component_type}

      #{code}

      def render(assigns) do
        ~H(<div></div>)
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
  use ExUnit.Case
  import ExUnit.CaptureIO

  defmodule ComponentWithRequiredDefaultSlot do
    use Surface.Component

    slot default, required: true
    slot header
    slot footer

    def render(assigns) do
      ~H"""
      <div>
        <slot name="header"/>
        <slot/>
        <slot name="footer"/>
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
      ~H"""
      <div>
        <slot name="header"/>
        <slot/>
        <slot name="footer"/>
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
          ~H"\""
          <ComponentWithRequiredDefaultSlot/>
          "\""
        end
      end
      """

      output =
        capture_io(:standard_error, fn ->
          {{:module, _, _, _}, _} =
            Code.eval_string(code, [], %{__ENV__ | file: "code.exs", line: 1})
        end)

      assert output =~ ~r"""
             missing required slot "default" for component <ComponentWithRequiredDefaultSlot>
               code.exs:6:\
             """
    end

    test "warn if required slot is not assigned (blank content)" do
      id = :erlang.unique_integer([:positive]) |> to_string()
      module = "TestComponentWithRequiredDefaultSlot_#{id}"

      code = """
      defmodule #{module} do
        use Surface.Component

        def render(assigns) do
          ~H"\""
          <ComponentWithRequiredDefaultSlot>
          </ComponentWithRequiredDefaultSlot>
          "\""
        end
      end
      """

      output =
        capture_io(:standard_error, fn ->
          {{:module, _, _, _}, _} =
            Code.eval_string(code, [], %{__ENV__ | file: "code.exs", line: 1})
        end)

      assert output =~ ~r"""
             missing required slot "default" for component <ComponentWithRequiredDefaultSlot>
               code.exs:6:\
             """
    end

    test "warn if required default slot is not assigned (other slots present)" do
      id = :erlang.unique_integer([:positive]) |> to_string()
      module = "TestComponentWithRequiredDefaultSlot_#{id}"

      code = """
      defmodule #{module} do
        use Surface.Component

        def render(assigns) do
          ~H"\""
          <ComponentWithRequiredDefaultSlot>
            <template slot="header">
              Header
            </template>
          </ComponentWithRequiredDefaultSlot>
          "\""
        end
      end
      """

      output =
        capture_io(:standard_error, fn ->
          {{:module, _, _, _}, _} =
            Code.eval_string(code, [], %{__ENV__ | file: "code.exs", line: 1})
        end)

      assert output =~ ~r"""
             missing required slot "default" for component <ComponentWithRequiredDefaultSlot>
               code.exs:6:\
             """
    end

    test "warn if a required named slot is not assigned" do
      id = :erlang.unique_integer([:positive]) |> to_string()
      module = "TestComponentWithRequiredSlots_#{id}"

      code = """
      defmodule #{module} do
        use Surface.Component

        def render(assigns) do
          ~H"\""
          <ComponentWithRequiredSlots>
          </ComponentWithRequiredSlots>
          "\""
        end
      end
      """

      output =
        capture_io(:standard_error, fn ->
          {{:module, _, _, _}, _} =
            Code.eval_string(code, [], %{__ENV__ | file: "code.exs", line: 1})
        end)

      assert output =~ ~r"""
             missing required slot "header" for component <ComponentWithRequiredSlots>
               code.exs:6:\
             """
    end

    test "do not validate required slots of non-existing components" do
      id = :erlang.unique_integer([:positive]) |> to_string()
      module = "TestComponentWithRequiredDefaultSlot_#{id}"

      code = """
      defmodule #{module} do
        use Surface.Component

        def render(assigns) do
          ~H"\""
          <ComponentWithRequiredDefaultSlot>
            <NonExisting>
              Don't validate me!
            </NonExisting>
          </ComponentWithRequiredDefaultSlot>
          "\""
        end
      end
      """

      error_message = "code.exs:7: module NonExisting is not loaded and could not be found"

      output =
        capture_io(:standard_error, fn ->
          assert_raise(CompileError, error_message, fn ->
            {{:module, _, _, _}, _} =
              Code.eval_string(code, [], %{__ENV__ | file: "code.exs", line: 1})
          end)
        end)

      assert output =~ ~r"cannot render <NonExisting> \(module NonExisting could not be loaded\)"
      assert output =~ ~r"  code.exs:7:"
    end
  end
end
