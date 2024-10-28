defmodule Surface.Components.ContextTest do
  use Surface.ConnCase, async: true

  alias Surface.Components.Context
  alias Surface.ContextTest.Components.ComponentWithExternalTemplateUsingContext
  alias Phoenix.LiveView.Socket

  import ExUnit.CaptureIO

  register_propagate_context_to_slots([
    __MODULE__.Outer,
    __MODULE__.OuterUsingPropContextPut,
    __MODULE__.OuterWithNamedSlots,
    __MODULE__.LiveComponentGetFromContextWithUpdate
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

  defmodule OuterUsingPropContextPut do
    use Surface.Component

    slot default

    def render(assigns) do
      ~F"""
      <div><#slot context_put={Surface.Components.ContextTest.Outer, field: "field from Outer"}/></div>
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

    data field, :any
    data other_field, :any

    def render(assigns) do
      assigns =
        assigns
        |> Context.copy_assign({ContextTest.Outer, :field})
        |> Context.copy_assign({ContextTest.InnerWrapper, :field}, as: :other_field)

      ~F"""
      <span id="field">{@field}</span>
      <span id="other_field">{@other_field}</span>
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

  describe "option :form_context in function components" do
    defmodule ComponentUsingFromContext do
      use Surface.Component

      alias Surface.Components.ContextTest.Outer

      prop field_with_scope, :any, from_context: {Outer, :field}
      prop field_without_scope, :any, from_context: :field

      data data_with_scope, :any, from_context: {Outer, :field}
      data data_without_scope, :any, from_context: :field

      def render(assigns) do
        ~F"""
        Prop with scope: {@field_with_scope}
        Prop without scope: {@field_without_scope}
        Data with scope: {@data_with_scope}
        Data without scope: {@data_without_scope}
        """
      end
    end

    test "use a value from the context as default value" do
      html =
        render_surface do
          ~F"""
          <Outer>
            <ComponentUsingFromContext/>
          </Outer>
          <Context put={field: "field without scope"}>
            <ComponentUsingFromContext/>
          </Context>
          """
        end

      assert html =~ "Prop with scope: field from Outer"
      assert html =~ "Prop without scope: field without scope"
      assert html =~ "Data with scope: field from Outer"
      assert html =~ "Data without scope: field without scope"
    end

    test "passing the prop overrides the value from the context" do
      html =
        render_surface do
          ~F"""
          <Outer>
            <ComponentUsingFromContext
              field_with_scope="field from prop with scope"
              field_without_scope="field from prop without scope"
            />
          </Outer>
          """
        end

      assert html =~ "Prop with scope: field from prop with scope"
      assert html =~ "Prop without scope: field from prop without scope"
    end
  end

  describe "option :form_context in live components" do
    defmodule LiveComponentUsingFromContext do
      use Surface.LiveComponent

      alias Surface.Components.ContextTest.Outer

      prop field_with_scope, :any, from_context: {Outer, :field}
      prop field_without_scope, :any, from_context: :field

      data data_with_scope, :any, from_context: {Outer, :field}
      data data_without_scope, :any, from_context: :field

      def render(assigns) do
        ~F"""
        <div>
          Prop with scope: {@field_with_scope}
          Prop without scope: {@field_without_scope}
          Data with scope: {@data_with_scope}
          Data without scope: {@data_without_scope}
        </div>
        """
      end
    end

    test "use a value from the context as default value" do
      html =
        render_surface do
          ~F"""
          <div>
            <Outer>
              <LiveComponentUsingFromContext id="1"/>
            </Outer>
            <Context put={field: "field without scope"}>
              <LiveComponentUsingFromContext id="2"/>
            </Context>
          </div>
          """
        end

      assert html =~ "Prop with scope: field from Outer"
      assert html =~ "Prop without scope: field without scope"
      assert html =~ "Data with scope: field from Outer"
      assert html =~ "Data without scope: field without scope"
    end

    test "passing the prop overrides the value from the context" do
      html =
        render_surface do
          ~F"""
          <Outer>
            <LiveComponentUsingFromContext
              id="1"
              field_with_scope="field from prop with scope"
              field_without_scope="field from prop without scope"
            />
          </Outer>
          """
        end

      assert html =~ "Prop with scope: field from prop with scope"
      assert html =~ "Prop without scope: field from prop without scope"
    end
  end

  describe "option :form_context in live components with update/2" do
    defmodule LiveComponentUsingFromContextWithUpdate do
      use Surface.LiveComponent

      alias Surface.Components.ContextTest.Outer

      prop field_with_scope, :any, from_context: {Outer, :field}
      prop field_without_scope, :any, from_context: :field

      data data_with_scope, :any, from_context: {Outer, :field}
      data data_without_scope, :any, from_context: :field

      data computed_value, :any

      @impl true
      def update(assigns, socket) do
        computed_value = [
          String.upcase(assigns.field_with_scope || ""),
          String.upcase(assigns.field_without_scope || ""),
          String.upcase(assigns.data_with_scope || ""),
          String.upcase(assigns.data_without_scope || "")
        ]

        socket =
          socket
          |> assign(assigns)
          |> assign(:computed_value, computed_value)

        {:ok, socket}
      end

      @impl true
      def render(assigns) do
        ~F"""
        <div>
          Prop with scope: {@field_with_scope}
          Prop without scope: {@field_without_scope}
          Data with scope: {@data_with_scope}
          Data without scope: {@data_without_scope}
          Computed value: {inspect(@computed_value)}
        </div>
        """
      end
    end

    test "use a value from the context if the related prop is not given" do
      html =
        render_surface do
          ~F"""
          <div>
            <Outer>
              <LiveComponentUsingFromContextWithUpdate id="1"/>
            </Outer>
            <Context put={field: "field without scope"}>
              <LiveComponentUsingFromContextWithUpdate id="2"/>
            </Context>
          </div>
          """
        end

      assert html =~ "Prop with scope: field from Outer"
      assert html =~ "Prop without scope: field without scope"
      assert html =~ "Data with scope: field from Outer"
      assert html =~ "Data without scope: field without scope"
    end

    test "passing the prop overrides the value from the context" do
      html =
        render_surface do
          ~F"""
          <Outer>
            <LiveComponentUsingFromContextWithUpdate
              id="1"
              field_with_scope="field from prop with scope"
              field_without_scope="field from prop without scope"
            />
          </Outer>
          """
        end

      assert html =~ "Prop with scope: field from prop with scope"
      assert html =~ "Prop without scope: field from prop without scope"
    end
  end

  describe "get in live component update/2" do
    defmodule LiveComponentGetFromContextWithUpdate do
      use Surface.LiveComponent

      alias Surface.Components.ContextTest.Outer

      slot default
      data data_with_scope, :any
      data data_without_scope, :any

      @impl true
      def update(assigns, socket) do
        socket =
          socket
          |> assign(assigns)
          |> assign(:data_with_scope, Context.get(socket, Outer, :field))
          |> assign(:data_without_scope, Context.get(socket, :field))
          |> Context.put(field: "updated field")

        {:ok, socket}
      end

      @impl true
      def render(assigns) do
        ~F"""
        <div>
          Data with scope: {@data_with_scope}
          Data without scope: {@data_without_scope}
          <#slot />
        </div>
        """
      end
    end

    test "can get and update context in update" do
      html =
        render_surface do
          ~F"""
          <div>
            <Outer>
              <LiveComponentGetFromContextWithUpdate id="1"/>
            </Outer>
            <Context put={field: "field without scope"}>
              <LiveComponentGetFromContextWithUpdate id="2">
                <RenderContext/>
              </LiveComponentGetFromContextWithUpdate>
            </Context>
          </div>
          """
        end

      assert html =~ "Data with scope: field from Outer"
      assert html =~ "Data without scope: field without scope"
      assert html =~ "updated field"
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

    test "put/3 throws ArgumentError argument error if the subject is not a socket/assigns, even with `__context__` key" do
      msg =
        "put/3 expects a socket or an assigns map from a function component as first argument, got: %{__context__: %{}}"

      assert_raise ArgumentError, msg, fn ->
        Context.put(%{__context__: %{}}, SomeScope, value: 1)
      end
    end

    test "get/3 throws ArgumentError if the subject is not a socket/assigns" do
      msg = "get/3 expects a socket or an assigns map from a function component as first argument, got: %{}"

      assert_raise ArgumentError, msg, fn ->
        Context.get(%{}, SomeScope, :value1)
      end
    end
  end

  describe "copy_assign/3" do
    test "copy a value from the context into the assigns (socket)" do
      socket =
        %Socket{}
        |> Context.put(Form, form: :fake_form)
        |> Context.put(field: :fake_field)
        |> Context.copy_assign({Form, :form})
        |> Context.copy_assign(:field)

      assert socket.assigns.form == :fake_form
      assert socket.assigns.field == :fake_field
    end

    test "overrides a value if already exists (socket)" do
      socket =
        %Socket{}
        |> Phoenix.Component.assign(:form, :existing_form)
        |> Phoenix.Component.assign(:field, :existing_field)
        |> Context.put(Form, form: :fake_form)
        |> Context.put(field: :fake_field)
        |> Context.copy_assign({Form, :form})
        |> Context.copy_assign(:field)

      assert socket.assigns.form == :fake_form
      assert socket.assigns.field == :fake_field
    end

    test "copy a value from the context into the assigns (assigns)" do
      assigns =
        %{__changed__: %{}}
        |> Context.put(Form, form: :fake_form)
        |> Context.put(field: :fake_field)
        |> Context.copy_assign({Form, :form})
        |> Context.copy_assign(:field)

      assert assigns.form == :fake_form
      assert assigns.field == :fake_field
    end

    test "overrides a value if already exists (assigns)" do
      assigns =
        %{__changed__: %{}}
        |> Phoenix.Component.assign(:form, :existing_form)
        |> Phoenix.Component.assign(:field, :existing_field)
        |> Context.put(Form, form: :fake_form)
        |> Context.put(field: :fake_field)
        |> Context.copy_assign({Form, :form})
        |> Context.copy_assign(:field)

      assert assigns.form == :fake_form
      assert assigns.field == :fake_field
    end

    test "option :as to store the value using a different key" do
      socket =
        %Socket{}
        |> Context.put(Form, form: :fake_form)
        |> Context.put(field: :fake_field)
        |> Context.copy_assign({Form, :form}, as: :my_form)
        |> Context.copy_assign(:field, as: :my_field)

      assert socket.assigns.my_form == :fake_form
      assert socket.assigns.my_field == :fake_field
    end
  end

  describe "maybe_copy_assign/3" do
    test "copy a value from the context if it hasn't been assigned yet (socket)" do
      socket =
        %Socket{}
        |> Context.put(Form, form: :fake_form)
        |> Context.put(field: :fake_field)
        |> Context.maybe_copy_assign({Form, :form})
        |> Context.maybe_copy_assign(:field)

      assert socket.assigns.form == :fake_form
      assert socket.assigns.field == :fake_field
    end

    test "don't copy the value if it's already been assigned (socket)" do
      socket =
        %Socket{}
        |> Phoenix.Component.assign(:form, :existing_form)
        |> Phoenix.Component.assign(:field, :existing_field)
        |> Context.put(Form, form: :form_from_context)
        |> Context.put(field: :field_from_context)
        |> Context.maybe_copy_assign({Form, :form})
        |> Context.maybe_copy_assign(:field)

      assert socket.assigns.form == :existing_form
      assert socket.assigns.field == :existing_field
    end

    test "copy a value from the context if it hasn't been assigned yet (assigns)" do
      assigns =
        %{__changed__: %{}}
        |> Context.put(Form, form: :fake_form)
        |> Context.put(field: :fake_field)
        |> Context.maybe_copy_assign({Form, :form})
        |> Context.maybe_copy_assign(:field)

      assert assigns.form == :fake_form
      assert assigns.field == :fake_field
    end

    test "don't copy the value if it's already been assigned (assigns)" do
      assigns =
        %{__changed__: %{}}
        |> Phoenix.Component.assign(:form, :existing_form)
        |> Phoenix.Component.assign(:field, :existing_field)
        |> Context.put(Form, form: :form_from_context)
        |> Context.put(field: :field_from_context)
        |> Context.maybe_copy_assign({Form, :form})
        |> Context.maybe_copy_assign(:field)

      assert assigns.form == :existing_form
      assert assigns.field == :existing_field
    end

    test "option :as to store the value using a different key" do
      socket =
        %Socket{}
        |> Context.put(Form, form: :fake_form)
        |> Context.put(field: :fake_field)
        |> Context.maybe_copy_assign({Form, :form}, as: :my_form)
        |> Context.maybe_copy_assign(:field, as: :my_field)

      assert socket.assigns.my_form == :fake_form
      assert socket.assigns.my_field == :fake_field
    end
  end

  describe "maybe_copy_assign!/3" do
    test "copy a value from the context if it hasn't been assigned yet (socket)" do
      socket =
        %Socket{}
        |> Context.put(Form, form: :fake_form)
        |> Context.put(field: :fake_field)
        |> Context.maybe_copy_assign!({Form, :form})
        |> Context.maybe_copy_assign!(:field)

      assert socket.assigns.form == :fake_form
      assert socket.assigns.field == :fake_field
    end

    test "don't copy the value if it's already been assigned (socket)" do
      socket =
        %Socket{}
        |> Phoenix.Component.assign(:form, :existing_form)
        |> Phoenix.Component.assign(:field, :existing_field)
        |> Context.put(Form, form: :form_from_context)
        |> Context.put(field: :field_from_context)
        |> Context.maybe_copy_assign!({Form, :form})
        |> Context.maybe_copy_assign!(:field)

      assert socket.assigns.form == :existing_form
      assert socket.assigns.field == :existing_field
    end

    test "copy a value from the context if it hasn't been assigned yet (assigns)" do
      assigns =
        %{__changed__: %{}}
        |> Context.put(Form, form: :fake_form)
        |> Context.put(field: :fake_field)
        |> Context.maybe_copy_assign!({Form, :form})
        |> Context.maybe_copy_assign!(:field)

      assert assigns.form == :fake_form
      assert assigns.field == :fake_field
    end

    test "don't copy the value if it's already been assigned (assigns)" do
      assigns =
        %{__changed__: %{}}
        |> Phoenix.Component.assign(:form, :existing_form)
        |> Phoenix.Component.assign(:field, :existing_field)
        |> Context.put(Form, form: :form_from_context)
        |> Context.put(field: :field_from_context)
        |> Context.maybe_copy_assign!({Form, :form})
        |> Context.maybe_copy_assign!(:field)

      assert assigns.form == :existing_form
      assert assigns.field == :existing_field
    end

    test "option :as to store the value using a different key" do
      socket =
        %Socket{}
        |> Context.put(Form, form: :fake_form)
        |> Context.put(field: :fake_field)
        |> Context.maybe_copy_assign!({Form, :form}, as: :my_form)
        |> Context.maybe_copy_assign!(:field, as: :my_field)

      assert socket.assigns.my_form == :fake_form
      assert socket.assigns.my_field == :fake_field
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
        Context.maybe_copy_assign!(%Socket{}, {Form, :form})
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

    test "pass context to child component using the put_context prop" do
      html =
        render_surface do
          ~F"""
          <OuterUsingPropContextPut>
            <Inner/>
          </OuterUsingPropContextPut>
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

      data field, :any
      data item, :any
      data rest, :list

      def render(%{list: [item | rest]} = assigns) do
        assigns =
          assigns
          |> Context.copy_assign({ContextTest.Outer, :field})
          |> assign(:item, item)
          |> assign(:rest, rest)

        ~F"""
        {@count}. {@item} - {@field}
        <Context put={ContextTest.Outer, field: "#{@field} #{@count}"}>
          <Recursive list={@rest} count={@count + 1}/>
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

      message = ~r"""
      code:2:
      #{maybe_ansi("error:")} invalid value for property "get". expected a scope \
      module \(optional\) along with a keyword list of bindings, \
      e.g. {Form, form: form} or {field: my_field}, \
      got: {ContextTest.Outer, field: \[field\]}.\
      """

      assert_raise(Surface.CompileError, message, fn ->
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

      assert_raise(
        Surface.CompileError,
        ~r/code:2:\n#{maybe_ansi("error:")} invalid value for property "get"/,
        fn ->
          compile_surface(code)
        end
      )
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

      assert_raise(
        Surface.CompileError,
        ~r/code:2:\n#{maybe_ansi("error:")} invalid value for property "get"/,
        fn ->
          compile_surface(code)
        end
      )
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

      message = ~r"""
      code:2:
      #{maybe_ansi("error:")} invalid value for property "put". expected a scope \
      module \(optional\) along with a keyword list of values, \
      e.g. {MyModule, field: @value, other: "other"} or {field: @value}, \
      got: {ContextTest.Outer, 123}.\
      """

      assert_raise(Surface.CompileError, message, fn ->
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

      assert_raise(
        Surface.CompileError,
        ~r/code:2:\n#{maybe_ansi("error:")} invalid value for property "put"/,
        fn ->
          compile_surface(code)
        end
      )
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

      assert_raise(
        Surface.CompileError,
        ~r/code:2:\n#{maybe_ansi("error:")} invalid value for property "put"/,
        fn ->
          compile_surface(code)
        end
      )
    end
  end

  describe "dead views" do
    defmodule DeadView do
      use Phoenix.Template, root: "support/dead_views"
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
      use Phoenix.Template, root: "support/dead_views"
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

      assert Phoenix.Template.render_to_string(DeadView, "index", "html", []) =~ expected
    end

    test "pass context to named slots" do
      assert Phoenix.Template.render_to_string(DeadViewNamedSlots, "index", "html", []) =~
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

    assert output =~ """
           using <Context put=...> without depending on any variable has been deprecated.

           If you're storing values in the context only to propagate them through slots, \
           use the `context_put` property instead.

           # Example

               <#slot context_put={assign: @assign} ... />

           If the values must be available to all other child components in the template, \
           use `Context.put/3` instead.

           # Example

               socket_or_assigns = Context.put(socket_or_assigns, timezone: "UTC")

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

    assert output =~ """
           using <Context put=...> without depending on any variable has been deprecated.

           If you're storing values in the context only to propagate them through slots, \
           use the `context_put` property instead.

           # Example

               <#slot context_put={__MODULE__, assign: @assign} ... />

           If the values must be available to all other child components in the template, \
           use `Context.put/3` instead.

           # Example

               socket_or_assigns = Context.put(socket_or_assigns, timezone: "UTC")

             code:6:\
           """
  end

  test "warn on using <#slot context_put=...>" do
    code = """
    defmodule Elixir.Surface.Components.ContextTest.WarnOnSlotPropContextPut do
      use Elixir.Surface.Component

      slot default

      def render(assigns) do
        ~F[<#slot context_put={form: :fake_form}/>]
      end
    end
    """

    message = ~r"""
    code.exs:7:
    #{maybe_ansi("error:")} components propagating context values through slots must be configured \
    as `propagate_context_to_slots: true`.

    In case you don't want to propagate any value, you need to explicitly \
    set `propagate_context_to_slots` to `false`.

    # Example

    config :surface, :components, \[
      {Surface.Components.ContextTest.WarnOnSlotPropContextPut, propagate_context_to_slots: true},
      ...
    \]

    This warning is emitted whenever a <#slot ...> uses the `context_put` prop or \
    it's placed inside a parent component that propagates context values through its slots.
    """

    assert_raise(Surface.CompileError, message, fn ->
      {{:module, _, _, _}, _} = Code.eval_string(code, [], %{__ENV__ | file: "code.exs", line: 1})
    end)
  end

  test "warn on using <#slot ...> inside a <Context put=...>" do
    code = """
    defmodule Elixir.Surface.Components.ContextTest.WarnOnContextPut do
      use Elixir.Surface.Component

      slot default

      def render(assigns) do
        ~F"\""
        <Context put={form: :fake_form}>
          <#slot context_put={form: :fake_form}/>]
        </Context>
        "\""
      end
    end
    """

    message = ~r"""
    code.exs:9:
    #{maybe_ansi("error:")} components propagating context values through slots must be configured \
    as `propagate_context_to_slots: true`.

    In case you don't want to propagate any value, you need to explicitly \
    set `propagate_context_to_slots` to `false`.

    # Example

    config :surface, :components, \[
      {Surface.Components.ContextTest.WarnOnContextPut, propagate_context_to_slots: true},
      ...
    \]

    This warning is emitted whenever a <#slot ...> uses the `context_put` prop or \
    it's placed inside a parent component that propagates context values through its slots.

    Current parent components propagating context values:

        \* `Surface.Components.Context` at line 8
    """

    assert_raise(Surface.CompileError, message, fn ->
      {{:module, _, _, _}, _} = Code.eval_string(code, [], %{__ENV__ | file: "code.exs", line: 1})
    end)
  end

  test "warn on using <#slot ...> inside components that propagate context through slots" do
    code = """
    defmodule Elixir.Surface.Components.ContextTest.WarnOnSlotInsideComponentPropagating do
      use Elixir.Surface.Component

      slot default

      def render(assigns) do
        ~F"\""
        <Outer>
          <OuterUsingPropContextPut>
            <#slot context_put={form: :fake_form}/>]
          </OuterUsingPropContextPut>
        </Outer>
        "\""
      end
    end
    """

    message = ~r"""
    code.exs:10:
    #{maybe_ansi("error:")} components propagating context values through slots must be configured \
    as `propagate_context_to_slots: true`\.

    In case you don't want to propagate any value, you need to explicitly \
    set `propagate_context_to_slots` to `false`\.

    # Example

    config :surface, :components, \[
      {Surface.Components.ContextTest.WarnOnSlotInsideComponentPropagating, propagate_context_to_slots: true},
      ...
    \]

    This warning is emitted whenever a <#slot ...> uses the `context_put` prop or \
    it's placed inside a parent component that propagates context values through its slots.

    Current parent components propagating context values:

        \* `Surface.Components.ContextTest.Outer` at line 8
        \* `Surface.Components.ContextTest.OuterUsingPropContextPut` at line 9
    """

    assert_raise(Surface.CompileError, message, fn ->
      {{:module, _, _, _}, _} = Code.eval_string(code, [], %{__ENV__ | file: "code.exs", line: 1})
    end)
  end

  test "warn on <Context get...> to tetrieve values generated outside the template" do
    code =
      quote do
        ~F"""
        <div>
          <Context
            get={form: form}
          >
            Hello!
          </Context>
        </div>
        """
      end

    output =
      capture_io(:standard_error, fn ->
        compile_surface(code)
      end)

    assert output =~ """
           using <Context get=.../> to retrieve values generated outside the template \
           has been deprecated. Use `from_context` instead and access the related assigns directly in the template.

           # Examples

               # as default value for an existing prop
               prop form, :form, from_context: {Form, :form}
               prop other, :any, from_context: :other

               # as internal state
               data form, :form, from_context: {Form, :form}
               data other, :any, from_context: :other

             code:2:\
           """
  end
end
