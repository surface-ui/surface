defmodule Surface.Components.ContextTest do
  use Surface.ConnCase, async: true

  alias Surface.Components.Context
  alias Surface.ContextTest.Components.ComponentWithExternalTemplateUsingContext
  alias Phoenix.LiveView.Socket

  import ExUnit.CaptureIO

  register_context_propagation([
    __MODULE__.Outer,
    __MODULE__.OuterWithNamedSlots
  ])

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
        <span :for={{_slot, index} <- Enum.with_index(@my_slot)}>
          <#slot name="my_slot" index={index}/>
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

  describe "put/3 and get/3" do
    test "puts/gets values to/from the socket's context" do
      socket = %Socket{}
      socket = Context.put(socket, value1: 1, value2: 2)

      assert Context.get(socket, :value1) == 1
      assert Context.get(socket, :value2) == 2
    end

    test "puts/gets values to/from the socket's context with scope" do
      socket = %Socket{}
      socket = Context.put(socket, SomeScope, value1: 1, value2: 2)

      assert Context.get(socket, SomeScope, :value1) == 1
      assert Context.get(socket, SomeScope, :value2) == 2
    end

    test "puts/gets values to/from the assigns's context" do
      assigns = %{__changed__: %{}}
      assigns = Context.put(assigns, value1: 1, value2: 2)

      assert Context.get(assigns, :value1) == 1
      assert Context.get(assigns, :value2) == 2
    end

    test "puts/gets values to/from the assigns's context with scope" do
      assigns = %{__changed__: %{}}
      assigns = Context.put(assigns, SomeScope, value1: 1, value2: 2)

      assert Context.get(assigns, SomeScope, :value1) == 1
      assert Context.get(assigns, SomeScope, :value2) == 2
    end

    test "values in different scopes don't conflict (socket)" do
      socket = %Socket{}
      socket = Context.put(socket, value: 1)
      socket = Context.put(socket, SomeScope, value: 2)
      socket = Context.put(socket, OtherScope, value: 3)

      assert Context.get(socket, :value) == 1
      assert Context.get(socket, SomeScope, :value) == 2
      assert Context.get(socket, OtherScope, :value) == 3
    end

    test "values in different scopes don't conflict (assigns)" do
      assigns = %{__changed__: %{}}
      assigns = Context.put(assigns, value: 1)
      assigns = Context.put(assigns, SomeScope, value: 2)
      assigns = Context.put(assigns, OtherScope, value: 3)

      assert Context.get(assigns, :value) == 1
      assert Context.get(assigns, SomeScope, :value) == 2
      assert Context.get(assigns, OtherScope, :value) == 3
    end

    test "put/3 throws ArgumentError argument error if the subject is not a socket/assigns" do
      msg = "put/3 expects a socket or an assigns map from a function component as first argument, got: %{}"

      assert_raise ArgumentError, msg, fn ->
        Context.put(%{}, SomeScope, value: 1)
      end
    end

    test "get/3 throws ArgumentError if the subject is not a socket/assigns" do
      msg = "get/3 expects a socket or an assigns map from a function component as first argument, got: %{}"

      assert_raise ArgumentError, msg, fn ->
        Context.get(%{}, SomeScope, :value1)
      end
    end
  end

  describe "maybe_copy_assign/3" do
    test "copy a value from the context if it hasn't been assigned yet (socket)" do
      socket =
        %Socket{}
        |> Context.put(Form, form: :fake_form)
        |> Context.put(field: :fake_field)
        |> Context.maybe_copy_assign(Form, :form)
        |> Context.maybe_copy_assign(:field)

      assert socket.assigns.form == :fake_form
      assert socket.assigns.field == :fake_field
    end

    test "don't copy the value if it's already been assigned (socket)" do
      socket =
        %Socket{}
        |> Phoenix.LiveView.assign(:form, :existing_form)
        |> Phoenix.LiveView.assign(:field, :existing_field)
        |> Context.put(Form, form: :form_from_context)
        |> Context.put(field: :field_from_context)
        |> Context.maybe_copy_assign(Form, :form)
        |> Context.maybe_copy_assign(:field)

      assert socket.assigns.form == :existing_form
      assert socket.assigns.field == :existing_field
    end

    test "copy a value from the context if it hasn't been assigned yet (assigns)" do
      assigns =
        %{__changed__: %{}}
        |> Context.put(Form, form: :fake_form)
        |> Context.put(field: :fake_field)
        |> Context.maybe_copy_assign(Form, :form)
        |> Context.maybe_copy_assign(:field)

      assert assigns.form == :fake_form
      assert assigns.field == :fake_field
    end

    test "don't copy the value if it's already been assigned (assigns)" do
      assigns =
        %{__changed__: %{}}
        |> Phoenix.LiveView.assign(:form, :existing_form)
        |> Phoenix.LiveView.assign(:field, :existing_field)
        |> Context.put(Form, form: :form_from_context)
        |> Context.put(field: :field_from_context)
        |> Context.maybe_copy_assign(Form, :form)
        |> Context.maybe_copy_assign(:field)

      assert assigns.form == :existing_form
      assert assigns.field == :existing_field
    end
  end

  describe "maybe_copy_assign!/3" do
    test "copy a value from the context if it hasn't been assigned yet (socket)" do
      socket =
        %Socket{}
        |> Context.put(Form, form: :fake_form)
        |> Context.put(field: :fake_field)
        |> Context.maybe_copy_assign!(Form, :form)
        |> Context.maybe_copy_assign!(:field)

      assert socket.assigns.form == :fake_form
      assert socket.assigns.field == :fake_field
    end

    test "don't copy the value if it's already been assigned (socket)" do
      socket =
        %Socket{}
        |> Phoenix.LiveView.assign(:form, :existing_form)
        |> Phoenix.LiveView.assign(:field, :existing_field)
        |> Context.put(Form, form: :form_from_context)
        |> Context.put(field: :field_from_context)
        |> Context.maybe_copy_assign!(Form, :form)
        |> Context.maybe_copy_assign!(:field)

      assert socket.assigns.form == :existing_form
      assert socket.assigns.field == :existing_field
    end

    test "copy a value from the context if it hasn't been assigned yet (assigns)" do
      assigns =
        %{__changed__: %{}}
        |> Context.put(Form, form: :fake_form)
        |> Context.put(field: :fake_field)
        |> Context.maybe_copy_assign!(Form, :form)
        |> Context.maybe_copy_assign!(:field)

      assert assigns.form == :fake_form
      assert assigns.field == :fake_field
    end

    test "don't copy the value if it's already been assigned (assigns)" do
      assigns =
        %{__changed__: %{}}
        |> Phoenix.LiveView.assign(:form, :existing_form)
        |> Phoenix.LiveView.assign(:field, :existing_field)
        |> Context.put(Form, form: :form_from_context)
        |> Context.put(field: :field_from_context)
        |> Context.maybe_copy_assign!(Form, :form)
        |> Context.maybe_copy_assign!(:field)

      assert assigns.form == :existing_form
      assert assigns.field == :existing_field
    end

    test "raise an error if the value is still `nil` after trying to copy it (with scope)" do
      message = """
      expected assign :form to have a value, got: `nil`.

      If you're expecting a value from a prop, make sure you're passing it.

      ## Example

          <YourComponent form={...}>

      If you expecting a value from the context, make sure you have used `Context.put/3` \
      to store the value in a parent component.

      ## Example

          Context.put(socket_or_assigns, Form, form: ...)

      If you expecting the value to come from a parent component's slot, make sure you add \
      the parent component to the `:propagate_context_to_slots` list in your config.

      ## Example

          config :surface, :propagate_context_to_slots, [
            # For module components
            ModuleComponentStoringTheValue,
            # For function components
            {FunctionComponentStoringTheValue, :func}
            ...
          ]
      """

      assert_raise(RuntimeError, message, fn ->
        Context.maybe_copy_assign!(%Socket{}, Form, :form)
      end)
    end

    test "raise an error if the value is still `nil` after trying to copy it (without scope)" do
      message = """
      expected assign :form to have a value, got: `nil`.

      If you're expecting a value from a prop, make sure you're passing it.

      ## Example

          <YourComponent form={...}>

      If you expecting a value from the context, make sure you have used `Context.put/3` \
      to store the value in a parent component.

      ## Example

          Context.put(socket_or_assigns, form: ...)

      If you expecting the value to come from a parent component's slot, make sure you add \
      the parent component to the `:propagate_context_to_slots` list in your config.

      ## Example

          config :surface, :propagate_context_to_slots, [
            # For module components
            ModuleComponentStoringTheValue,
            # For function components
            {FunctionComponentStoringTheValue, :func}
            ...
          ]
      """

      assert_raise(RuntimeError, message, fn ->
        Context.maybe_copy_assign!(%Socket{}, :form)
      end)
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

    defmodule Recursive do
      use Surface.Component

      alias Surface.Components.ContextTest

      prop list, :list
      prop count, :integer, default: 1

      def render(%{list: [item | rest]} = assigns) do
        ~F"""
        <Context get={ContextTest.Outer, field: field}>
          {@count}. {item} - {field}
          <Context put={ContextTest.Outer, field: "#{field} #{@count}"}>
            <Recursive list={rest} count={@count + 1}/>
          </Context>
        </Context>
        """
      end

      def render(assigns), do: ~F""
    end

    test "context propagation in recursive components" do
      html =
        render_surface do
          ~F"""
          <Outer>
            <Recursive list={["a", "b", "c"]}/>
          </Outer>
          """
        end

      assert html =~ """
             1. a - field from Outer
               2. b - field from Outer 1
               3. c - field from Outer 1 2
             """
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

  test "warn on <Context put={expr}> where `expr` is not a literal nor has any variable" do
    code =
      quote do
        ~F"""
        <div>
          {#if var = 1}
            <Context
              put={var: var}
              put={literal: "literal"}
              put={assign: @assign}
            >
              "Hello"
            </Context>
          {/if}
        </div>
        """
      end

    output =
      capture_io(:standard_error, fn ->
        compile_surface(code)
      end)

    assert output =~ ~r"""
           using <Context put=\{...\}> to store values that don't depend on variables is not recommended.

           Hint: If the values you're storing in the context depend only on the component's assigns, use `Context.put/3` instead.

           # On live components or live views
           socket = Context.put\(socket, timezone: "UTC"\)

           # On components
           assigns = Context.put\(assigns, timezone: "UTC"\)

             code:6:\
           """
  end

  test "warn on <Context put={scope, expr}> where `expr` is not a literal nor has any variable" do
    code =
      quote do
        ~F"""
        <div>
          {#if var = 1}
            <Context
              put={__MODULE__, var: var}
              put={__MODULE__, literal: "literal"}
              put={__MODULE__, assign: @assign}
            >
              "Hello"
            </Context>
          {/if}
        </div>
        """
      end

    output =
      capture_io(:standard_error, fn ->
        compile_surface(code)
      end)

    assert output =~ ~r"""
           using <Context put=\{...\}> to store values that don't depend on variables is not recommended.

           Hint: If the values you're storing in the context depend only on the component's assigns, use `Context.put/3` instead.

           # On live components or live views
           socket = Context.put\(socket, timezone: "UTC"\)

           # On components
           assigns = Context.put\(assigns, timezone: "UTC"\)

             code:6:\
           """
  end
end
