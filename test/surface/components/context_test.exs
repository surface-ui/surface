defmodule Surface.Components.ContextTest do
  use Surface.ConnCase, async: true

  alias Surface.Components.Context
  alias Surface.ContextTest.Components.ComponentWithExternalTemplateUsingContext

  defmodule Outer do
    use Surface.Component

    slot default

    def render(assigns) do
      ~F"""
      <Context put={__MODULE__, field: "field from Outer"}>
        <div><#slot/></div>
      </Context>
      """
    end
  end

  defmodule RenderContext do
    use Surface.Component

    def render(assigns) do
      ~F"""
      Context: {inspect(@__context__)}
      """
    end
  end

  defmodule Inner do
    use Surface.Component

    alias Surface.Components.ContextTest

    def render(assigns) do
      ~F"""
      <Context
        get={ContextTest.Outer, field: field}
        get={ContextTest.InnerWrapper, field: other_field}>
        <span id="field">{field}</span>
        <span id="other_field">{other_field}</span>
      </Context>
      """
    end
  end

  defmodule InnerWrapper do
    use Surface.Component

    def render(assigns) do
      ~F"""
      <Context put={__MODULE__, field: "field from InnerWrapper"}>
        <Inner />
      </Context>
      """
    end
  end

  defmodule InnerWithOptionAs do
    use Surface.Component

    alias Surface.Components.ContextTest

    def render(assigns) do
      ~F"""
      <Context get={ContextTest.Outer, field: my_field}>
        <span>{my_field}</span>
      </Context>
      """
    end
  end

  defmodule OuterWithNamedSlots do
    use Surface.Component

    slot my_slot

    def render(assigns) do
      ~F"""
      <Context put={field: "field from OuterWithNamedSlots"}>
        <span :for={slot <- @my_slot}>
          <#slot {slot} />
        </span>
      </Context>
      """
    end
  end

  defmodule InputsWithNestedField do
    use Surface.Component

    alias Surface.Components.Form.{Inputs, Field, TextInput}

    def render(assigns) do
      ~F"""
      <Inputs for={:children}>
        <Field name={:name}>
          <TextInput/>
        </Field>
      </Inputs>
      """
    end
  end

  describe "in components" do
    test "pass context to child component" do
      html =
        render_surface do
          ~F"""
          <Outer>
            <Inner/>
          </Outer>
          """
        end

      assert html =~ """
             <span id="field">field from Outer</span>\
             """
    end

    test "pass context to child component using external template" do
      html =
        render_surface do
          ~F"""
          <Outer>
            <ComponentWithExternalTemplateUsingContext/>
          </Outer>
          """
        end

      assert html =~ """
             <div>field from Outer</div>\
             """
    end

    test "pass context to child component using :as option" do
      html =
        render_surface do
          ~F"""
          <Outer>
            <InnerWithOptionAs/>
          </Outer>
          """
        end

      assert html =~ """
             <div>
               <span>field from Outer</span>
             </div>
             """
    end

    test "pass context down the tree of components" do
      html =
        render_surface do
          ~F"""
          <Outer>
            <InnerWrapper />
          </Outer>
          """
        end

      assert html =~ """
             <span id="field">field from Outer</span>\
             """
    end

    test "context assigns are scoped by their parent components" do
      html =
        render_surface do
          ~F"""
          <Outer>
            <InnerWrapper/>
          </Outer>
          """
        end

      assert html =~ """
             <span id="field">field from Outer</span>
               <span id="other_field">field from InnerWrapper</span>
             """
    end

    test "reset context after the component" do
      html =
        render_surface do
          ~F"""
          <Outer>
            <Inner/>
          </Outer>
          <RenderContext/>
          """
        end

      assert html =~ """
             Context: %{}
             """
    end

    test "pass context to named slots" do
      html =
        render_surface do
          ~F"""
          <OuterWithNamedSlots>
            <:my_slot>
              <Context get={field: field}>
                {field}
              </Context>
            </:my_slot>
          </OuterWithNamedSlots>
          """
        end

      assert html =~ "field from OuterWithNamedSlots"
    end

    test "using form and field stored in the context" do
      alias Surface.Components.Form

      html =
        render_surface do
          ~F"""
          <Form for={:parent} opts={csrf_token: "test"}>
            <InputsWithNestedField/>
          </Form>
          """
        end

      assert html =~ """
             <form action="#" method="post">
                 <input name="_csrf_token" type="hidden" value="test">
               <div>
               <input id="parent_children_name" name="parent[children][name]" type="text">
             </div>
             </form>
             """
    end
  end

  describe "inside function components" do
    defmodule FunctionComponents do
      def pass_to_child(assigns) do
        ~F"""
        <Outer>
          <Inner/>
        </Outer>
        """
      end

      def pass_to_tree_of_components(assigns) do
        ~F"""
        <Outer>
          <InnerWrapper />
        </Outer>
        """
      end
    end

    test "pass context to child component" do
      html =
        render_surface do
          ~F"""
          <FunctionComponents.pass_to_child/>
          """
        end

      assert html =~ """
             <span id="field">field from Outer</span>\
             """
    end

    test "pass context down the tree of components" do
      html =
        render_surface do
          ~F"""
          <FunctionComponents.pass_to_tree_of_components/>
          """
        end

      assert html =~ """
             <span id="field">field from Outer</span>\
             """
    end
  end

  describe "validate property :get" do
    test "raise compile error when passing invalid bindings" do
      code =
        quote do
          ~F"""
          <Context
            get={ContextTest.Outer, field: [field]}>
            {field}
          </Context>
          """
        end

      message = """
      code:2: invalid value for property "get". expected a scope \
      module (optional) along with a keyword list of bindings, \
      e.g. {Form, form: form} or {field: my_field}, \
      got: {ContextTest.Outer, field: [field]}.\
      """

      assert_raise(CompileError, message, fn ->
        compile_surface(code)
      end)
    end

    test "raise compile error when passing no bindings" do
      code =
        quote do
          ~F"""
          <Context
            get={ContextTest.Outer}>
            {field}
          </Context>
          """
        end

      assert_raise(CompileError, ~r/code:2: invalid value for property "get"/, fn ->
        compile_surface(code)
      end)
    end

    test "raise compile error when passing invalid scope" do
      code =
        quote do
          ~F"""
          <Context
            get={123, field: field}>
            {field}
          </Context>
          """
        end

      assert_raise(CompileError, ~r/code:2: invalid value for property "get"/, fn ->
        compile_surface(code)
      end)
    end
  end

  describe "validate property :put" do
    test "raise compile error when passing invalid values" do
      code =
        quote do
          ~F"""
          <Context
            put={ContextTest.Outer, 123}>
            Inner Content
          </Context>
          """
        end

      message = """
      code:2: invalid value for property "put". expected a scope \
      module (optional) along with a keyword list of values, \
      e.g. {MyModule, field: @value, other: "other"} or {field: @value}, \
      got: {ContextTest.Outer, 123}.\
      """

      assert_raise(CompileError, message, fn ->
        compile_surface(code)
      end)
    end

    test "raise compile error when passing no values" do
      code =
        quote do
          ~F"""
          <Context
            put={ContextTest.Outer}>
            Inner content
          </Context>
          """
        end

      assert_raise(CompileError, ~r/code:2: invalid value for property "put"/, fn ->
        compile_surface(code)
      end)
    end

    test "raise compile error when passing invalid scope" do
      code =
        quote do
          ~F"""
          <Context
            put={123, field: field}>
            Inner content
          </Context>
          """
        end

      assert_raise(CompileError, ~r/code:2: invalid value for property "put"/, fn ->
        compile_surface(code)
      end)
    end
  end

  describe "dead views" do
    defmodule DeadView do
      use Phoenix.View, root: "support/dead_views"
      import Surface

      def render("index.html", assigns) do
        ~F"""
        <Outer>
          <InnerWrapper />
        </Outer>
        """
      end
    end

    defmodule DeadViewNamedSlots do
      use Phoenix.View, root: "support/dead_views"
      import Surface

      def render("index.html", assigns) do
        ~F"""
        <OuterWithNamedSlots>
          <:my_slot>
            <Context get={field: field}>
              {field}
            </Context>
          </:my_slot>
        </OuterWithNamedSlots>
        """
      end
    end

    test "pass context down the tree of components" do
      expected = ~S(<span id="field">field from Outer</span>)

      assert Phoenix.View.render_to_string(DeadView, "index.html", []) =~ expected
    end

    test "pass context to named slots" do
      assert Phoenix.View.render_to_string(DeadViewNamedSlots, "index.html", []) =~
               "field from OuterWithNamedSlots"
    end
  end
end
