defmodule Surface.APITest do
  use ExUnit.Case
  import ExUnit.CaptureIO

  defmodule ContextSetter do
    use Surface.Component

    @doc """
    The Form struct defined by the parent <Form/> component.
    """
    context set form, :form

    def init_context(_assigns) do
      {:ok, form: :fake}
    end

    def render(assigns) do
      ~H"""
      """
    end
  end

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

  test "raise error at the right line" do
    code = "property label, :unknown_type"
    message = ~r/code:4/

    assert_raise(CompileError, message, fn -> eval(code) end)
  end

  test "validate type" do
    code = "property label, {a, b}"
    message = ~r/invalid type {a, b} for property label.\nExpected one of \[:any/

    assert_raise(CompileError, message, fn -> eval(code) end)
  end

  test "validate options" do
    code = "property label, :string, {:a, :b}"

    message =
      ~r/invalid options for property label. Expected a keyword list of options, got: {:a, :b}/

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
    code = "property label, :string, required: 1"
    message = ~r/invalid value for option :required. Expected a boolean, got: 1/

    assert_raise(CompileError, message, fn -> eval(code) end)
  end

  test "validate :values" do
    code = "property label, :string, values: 1"
    message = ~r/invalid value for option :values. Expected a list of values, got: 1/

    assert_raise(CompileError, message, fn -> eval(code) end)
  end

  test "validate duplicate assigns" do
    code = """
    property label, :string
    property label, :string
    """

    message = ~r"""
    cannot use name "label". \
    There's already a property assign with the same name at line 4\
    """

    assert_raise(CompileError, message, fn -> eval(code) end)

    code = """
    property label, :string
    data label, :string
    """

    message = ~r/cannot use name "label". There's already a property/
    assert_raise(CompileError, message, fn -> eval(code) end)

    code = """
    data label, :string
    context get label, from: Surface.APITest.ContextSetter
    """

    message = ~r"""
    cannot use name "label". There's already a data assign with the same name at line 4.

    Hint: you can use the :as option to set another name for the context assign.\
    """

    assert_raise(CompileError, message, fn -> eval(code) end)

    code = """
    property form, :form
    context set form, :form
    """

    message = ~r"""
    cannot use name "form". There's already a property assign with the same name at line 4.

    Hint: if you only need this context assign in the child components, \
    you can set option :scope as :only_children to solve the issue.\
    """

    assert_raise(CompileError, message, fn -> eval(code) end)

    code = """
    context set form, :form
    property form, :form
    """

    message = ~r/cannot use name "form". There's already a context/
    assert_raise(CompileError, message, fn -> eval(code) end)
  end

  test "allow context :set with existing assign name when :scope is :only_children" do
    code = """
    property form, :form
    context set form, :form, scope: :only_children
    """

    assert {:ok, _} = eval(code)
  end

  test "allow context :get with existing assign name when using :as" do
    code = """
    property form, :form
    context get form, from: Surface.APITest.ContextSetter, as: :my_form
    """

    assert {:ok, _} = eval(code)
  end

  test "accept invalid quoted expressions like literal maps as default value" do
    code = """
    property map, :map, default: %{a: 1, b: 2}
    """

    assert {:ok, module} = eval(code)
    assert module.__get_prop__(:map)[:opts][:default] == %{a: 1, b: 2}
  end

  describe "property" do
    test "validate name" do
      code = "property {a, b}, :string"
      message = ~r/invalid property name. Expected a variable name, got: {a, b}/

      assert_raise(CompileError, message, fn ->
        eval(code)
      end)
    end

    test "common type options" do
      code = "property count, :integer, required: false, default: 0, values: [0, 1, 2]"
      assert {:ok, _} = eval(code)
    end

    test "validate unknown type options" do
      code = "property label, :string, a: 1"
      message = ~r/unknown option :a. Available options: \[:required, :default, :values\]/

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
      message = ~r/unknown option :a. Available options: \[:required, :props\]/

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

        property label, :string
        property items, :list

        slot default, props: [item: ^unknown]

        def render(assigns), do: ~H()
      end
      """

      message = """
      code.exs:7: cannot bind slot prop `item` to property `unknown`. \
      Expected a existing property after `^`, got: an undefined property `unknown`.

      Hint: Available properties are [:items, :label]\
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

        property label, :string

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

  describe "context :set" do
    test "validate action without options" do
      code = "context unknown name, :string"
      message = ~r/invalid context action. Expected :get or :set, got: :unknown/

      assert_raise(CompileError, message, fn ->
        eval(code)
      end)
    end

    test "validate action with options" do
      code = "context unknown name, :string, scope: :only_children"

      message = ~r"""
      invalid use of context. Usage: `context get name, opts` or \
      `context set name, type, opts \\ \[\]`\
      """

      assert_raise(CompileError, message, fn ->
        eval(code)
      end)
    end

    test "validate name" do
      code = "context set {a, b}, :string"
      message = ~r/invalid context name. Expected a variable name, got: {a, b}/

      assert_raise(CompileError, message, fn ->
        eval(code)
      end)
    end

    test "validate type" do
      code = "context set name, scope: :only_children"
      message = ~r/no type defined for context set. Type is required after the name./

      assert_raise(CompileError, message, fn ->
        eval(code)
      end)

      code = "context set name"

      assert_raise(CompileError, message, fn ->
        eval(code)
      end)
    end

    test "valid options" do
      code = "context set field, :atom, scope: :only_children"
      assert {:ok, _} = eval(code)
    end

    test "validate :scope" do
      code = "context set field, :atom, scope: :unknown"

      message =
        ~r/invalid value for option :scope. Expected :only_children or :self_and_children, got: :unknown/

      assert_raise(CompileError, message, fn ->
        eval(code)
      end)
    end

    test "no required options" do
      code = "context set field, :atom"
      assert {:ok, _} = eval(code)
    end

    test "unknown options" do
      code = "context set label, :string, a: 1"
      message = ~r/unknown option :a. Available options: \[:scope\]/

      assert_raise(CompileError, message, fn ->
        eval(code)
      end)
    end

    test "warn on context :set if there's no init_context/1" do
      id = :erlang.unique_integer([:positive]) |> to_string()
      module = "TestLiveComponent_#{id}"

      code = """
      defmodule #{module} do
        use Surface.LiveComponent

        context set field, :atom

        def render(assigns) do
          ~H(<div></div>)
        end
      end
      """

      output =
        capture_io(:standard_error, fn ->
          {{:module, _, _, _}, _} =
            Code.eval_string(code, [], %{__ENV__ | file: "code.exs", line: 1})
        end)

      assert output =~ ~r"""
             context assign "field" not initialized. You should implement an init_context/1 \
             callback and initialize its value by returning {:ok, field: ...}
               code.exs:4:\
             """
    end
  end

  describe "context :get" do
    test "validate action" do
      code = "context unknown name, from: Surface.APITest.ContextSetter"
      message = ~r/invalid context action. Expected :get or :set, got: :unknown/

      assert_raise(CompileError, message, fn ->
        eval(code)
      end)
    end

    test "valid options" do
      code = """
      context get form, from: Surface.APITest.ContextSetter, as: :my_form
      """

      assert {:ok, _} = eval(code)
    end

    test "invalid :from" do
      code = """
      context get form, from: 1
      """

      message = ~r/invalid value for option :from. Expected a module, got: 1/

      assert_raise(CompileError, message, fn ->
        eval(code)
      end)
    end

    test "option :from is required" do
      code = """
      context get form, as: :my_form
      """

      message = ~r/the following options are required: \[:from\]/

      assert_raise(CompileError, message, fn ->
        eval(code)
      end)

      code = """
      context get form
      """

      assert_raise(CompileError, message, fn ->
        eval(code)
      end)
    end

    test "invalid :as" do
      code = """
      context get form, from: Surface.APITest.ContextSetter, as: 1
      """

      message = ~r/invalid value for option :as. Expected an atom, got: 1/

      assert_raise(CompileError, message, fn ->
        eval(code)
      end)
    end

    test "cannot define the type of the assign" do
      code = "context get name, :string"

      message = ~r"""
      cannot redefine the type of the assign when using action :get. \
      The type is already defined by a parent component using action :set\
      """

      assert_raise(CompileError, message, fn ->
        eval(code)
      end)
    end

    test "unknown options" do
      code = "context get label, from: Surface.APITest.ContextSetter, a: 1"
      message = ~r/unknown option :a. Available options: \[:from, :as\]/

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

  defp eval(code) do
    id = :erlang.unique_integer([:positive]) |> to_string()
    module_name = "TestLiveComponent_#{id}"

    comp_code = """
    defmodule #{module_name} do
      use Surface.LiveComponent

      #{code}

      def init_context(_assigns) do
        {:ok, field: nil}
      end

      def render(assigns) do
        ~H(<div></div>)
      end
    end
    """

    {{:module, module, _, _}, _} = Code.eval_string(comp_code, [], file: "code")
    {:ok, module}
  end

  defp get_docs(module) do
    {:docs_v1, _, _, "text/markdown", %{"en" => docs}, %{}, _} = Code.fetch_docs(module)
    docs
  end
end
