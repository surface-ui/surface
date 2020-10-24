defmodule ContextTest do
  use ExUnit.Case, async: true

  import Surface
  import ComponentTestHelper

  alias Surface.Components.Context

  defmodule Outer do
    use Surface.Component

    def render(assigns) do
      ~H"""
      <Context put={{ __MODULE__, field: "field from Outer" }}>
        <div><slot/></div>
      </Context>
      """
    end
  end

  defmodule RenderContext do
    use Surface.Component

    def render(assigns) do
      ~H"""
      Context: {{ inspect(@__context__) }}
      """
    end
  end

  defmodule Inner do
    use Surface.Component

    def render(assigns) do
      ~H"""
      <Context
        get={{ ContextTest.Outer, field: field }}
        get={{ ContextTest.InnerWrapper, field: other_field }}>
        <span id="field">{{ field }}</span>
        <span id="other_field">{{ other_field }}</span>
      </Context>
      """
    end
  end

  defmodule InnerWrapper do
    use Surface.Component

    def render(assigns) do
      ~H"""
      <Context put={{ __MODULE__, field: "field from InnerWrapper" }}>
        <Inner />
      </Context>
      """
    end
  end

  defmodule InnerWithOptionAs do
    use Surface.Component

    def render(assigns) do
      ~H"""
      <Context get={{ ContextTest.Outer, field: my_field }}>
        <span>{{ my_field }}</span>
      </Context>
      """
    end
  end

  defmodule OuterWithNamedSlots do
    use Surface.Component

    slot my_slot

    def render(assigns) do
      ~H"""
      <Context put={{ field: "field from OuterWithNamedSlots" }}>
        <span :for={{ {_slot, index} <- Enum.with_index(@my_slot) }}>
          <slot name="my_slot" index={{ index }}/>
        </span>
      </Context>
      """
    end
  end

  test "pass context to child component" do
    code =
      quote do
        ~H"""
        <Outer>
          <Inner/>
        </Outer>
        """
      end

    assert render_live(code) =~ """
           <span id="field">field from Outer</span>\
           """
  end

  test "pass context to child component using :as option" do
    code =
      quote do
        ~H"""
        <Outer>
          <InnerWithOptionAs/>
        </Outer>
        """
      end

    assert render_live(code) =~ """
           <div><span>field from Outer</span></div>
           """
  end

  test "pass context down the tree of components" do
    code =
      quote do
        ~H"""
        <Outer>
          <InnerWrapper />
        </Outer>
        """
      end

    assert render_live(code) =~ """
           <span id="field">field from Outer</span>\
           """
  end

  test "context assingns are scoped by their parent components" do
    code =
      quote do
        ~H"""
        <Outer>
          <InnerWrapper/>
        </Outer>
        """
      end

    assert render_live(code) =~ """
           <span id="field">field from Outer</span>\
           <span id="other_field">field from InnerWrapper</span>\
           """
  end

  test "reset context after the component" do
    code =
      quote do
        ~H"""
        <Outer>
          <Inner/>
        </Outer>
        <RenderContext/>
        """
      end

    assert render_live(code) =~ """
           Context: %{}
           """
  end

  test "pass context to named slots" do
    code =
      quote do
        ~H"""
        <OuterWithNamedSlots>
          <template slot="my_slot">
            <Context get={{ field: field }}>
              {{ field }}
            </Context>
          </template>
        </OuterWithNamedSlots>
        """
      end

    assert render_live(code) =~ "field from OuterWithNamedSlots"
  end

  describe "validate property :get" do
    test "raise compile error when passing invalid bindings" do
      code =
        quote do
          ~H"""
          <Context
            get={{ ContextTest.Outer, field: [field] }}>
            {{ field }}
          </Context>
          """
        end

      message = """
      code:2: invalid value for property "get". expected a scope \
      module (optional) along with a keyword list of bindings, \
      e.g. {{ Form, form: form }} or {{ field: my_field }}, \
      got: {{ ContextTest.Outer, field: [field] }}.\
      """

      assert_raise(CompileError, message, fn ->
        render_live(code)
      end)
    end

    test "raise compile error when passing no bindings" do
      code =
        quote do
          ~H"""
          <Context
            get={{ ContextTest.Outer }}>
            {{ field }}
          </Context>
          """
        end

      assert_raise(CompileError, ~r/code:2: invalid value for property "get"/, fn ->
        render_live(code)
      end)
    end

    test "raise compile error when passing invalid scope" do
      code =
        quote do
          ~H"""
          <Context
            get={{ 123, field: field }}>
            {{ field }}
          </Context>
          """
        end

      assert_raise(CompileError, ~r/code:2: invalid value for property "get"/, fn ->
        render_live(code)
      end)
    end
  end

  describe "validate property :put" do
    test "raise compile error when passing invalid values" do
      code =
        quote do
          ~H"""
          <Context
            put={{ ContextTest.Outer, 123 }}>
            <slot/>
          </Context>
          """
        end

      message = """
      code:2: invalid value for property "put". expected a scope \
      module (optional) along with a keyword list of values, \
      e.g. {{ MyModule, field: @value, other: "other" }} or {{ field: @value }}, \
      got: {{ ContextTest.Outer, 123 }}.\
      """

      assert_raise(CompileError, message, fn ->
        render_live(code)
      end)
    end

    test "raise compile error when passing no values" do
      code =
        quote do
          ~H"""
          <Context
            put={{ ContextTest.Outer }}>
            <slot/>
          </Context>
          """
        end

      assert_raise(CompileError, ~r/code:2: invalid value for property "put"/, fn ->
        render_live(code)
      end)
    end

    test "raise compile error when passing invalid scope" do
      code =
        quote do
          ~H"""
          <Context
            put={{ 123, field: field }}>
            <slot/>
          </Context>
          """
        end

      assert_raise(CompileError, ~r/code:2: invalid value for property "put"/, fn ->
        render_live(code)
      end)
    end
  end
end
