defmodule Mix.Tasks.Compile.Surface.ValidateComponentsTest do
  use ExUnit.Case, async: false

  import Surface.LiveViewTest

  alias Mix.Tasks.Compile.Surface.ValidateComponents
  alias Mix.Task.Compiler.Diagnostic
  alias Mix.Tasks.Compile.Surface.ValidateComponentsTest.Components

  defmodule StringProp do
    use Surface.Component
    prop text, :string
    def render(assigns), do: ~F[{@text}]
  end

  test "should return diagnostic when unkwnown prop is passed to Component" do
    component =
      quote do
        ~F"""
          <StringProp unknown />
        """
      end
      |> compile_surface()

    diagnostics = ValidateComponents.validate([component])

    assert diagnostics == [
             %Diagnostic{
               compiler_name: "Surface",
               details: nil,
               file: Path.expand("code"),
               message: "Unknown property \"unknown\" for component <StringProp>",
               position: {1, 15},
               severity: :warning
             }
           ]
  end

  test "should not validate __caller_scope_id__ as unkwnown prop" do
    component =
      quote do
        ~F"""
        <style>
          .p {}
        </style>
        <StringProp />
        """
      end
      |> compile_surface()

    diagnostics = ValidateComponents.validate([component])

    assert diagnostics == []
  end

  defmodule RequiredPropTitle do
    use Surface.Component
    prop title, :string, required: true
    def render(assigns), do: ~F"{@title}"
  end

  test "should return diagnostic when missing required prop" do
    component =
      quote do
        ~F[<RequiredPropTitle />]
      end
      |> compile_surface()

    diagnostics = ValidateComponents.validate([component])

    assert diagnostics == [
             %Diagnostic{
               compiler_name: "Surface",
               details: nil,
               file: Path.expand("code"),
               message: "missing required property \"title\" for component <RequiredPropTitle>",
               position: {0, 2},
               severity: :warning
             }
           ]
  end

  test "should not return diagnostic when :props directive is present" do
    component =
      quote do
        ~F"""
        <RequiredPropTitle :props={%{}}/>
        <RequiredPropTitle {...%{}} />
        """
      end
      |> compile_surface()

    diagnostics = ValidateComponents.validate([component])
    assert diagnostics == []
  end

  defmodule LiveComponentHasRequiredIdProp do
    use Surface.LiveComponent
    def render(assigns), do: ~F"<div />"
  end

  test "should return diagnostic when missing automatically define id prop for LiveComponent" do
    component =
      quote do
        ~F"""
        <div>
          <LiveComponentHasRequiredIdProp />
        </div>
        """
      end
      |> compile_surface()

    diagnostics = ValidateComponents.validate([component])

    assert diagnostics == [
             %Mix.Task.Compiler.Diagnostic{
               compiler_name: "Surface",
               details: nil,
               file: Path.expand("code"),
               message: ~S"""
               missing required property "id" for component <LiveComponentHasRequiredIdProp>

               Hint: Components using `Surface.LiveComponent` automatically define a required `id` prop to make them stateful.
               If you meant to create a stateless component, you can switch to `use Surface.Component`.
               """,
               position: {2, 12},
               severity: :warning
             }
           ]
  end

  test "should return diagnostic when a directive is specified multiple times in a component" do
    component =
      quote do
        ~F[<StringProp :if={true} :if={false} />]
      end
      |> compile_surface()

    diagnostics = ValidateComponents.validate([component])

    assert diagnostics == [
             %Mix.Task.Compiler.Diagnostic{
               compiler_name: "Surface",
               details: nil,
               file: Path.expand("code"),
               message: ~S"""
               the directive `if` has been passed multiple times. Considering only the last value.

               Hint: remove all redundant definitions.
               """,
               position: {0, 24},
               severity: :warning
             }
           ]
  end

  defmodule MacroWithRequiredPropTitle do
    use Surface.MacroComponent
    prop title, :string, required: true
    prop body, :string, required: true

    def expand(attributes, content, _meta) do
      title = Surface.AST.find_attribute_value(attributes, :title)
      body = Surface.AST.find_attribute_value(attributes, :body)

      quote_surface do
        ~F"""
        {^title}
        {^body}
        """
      end
    end
  end

  test "should return diagnostic when missing required prop for macro component" do
    component =
      quote do
        alias MacroWithRequiredPropTitle, as: Macro

        ~F"""
          <#Macro body="body text" />
        """
      end
      |> compile_surface()

    diagnostics = ValidateComponents.validate([component])

    assert diagnostics == [
             %Diagnostic{
               compiler_name: "Surface",
               details: nil,
               file: Path.expand("code"),
               message: "missing required property \"title\" for component <#Macro>",
               position: {1, 4},
               severity: :warning
             }
           ]
  end

  test "should not return diagnostic when required prop is passed to macro component" do
    component =
      quote do
        alias MacroWithRequiredPropTitle, as: Macro
        ~F[<#Macro title="title text" body="body text" />]
      end
      |> compile_surface()

    diagnostics = ValidateComponents.validate([component])
    assert diagnostics == []
  end

  test "should return diagnostic on .sface file when missing required prop" do
    diagnostics = ValidateComponents.validate([Components.LiveViewWithExternalTemplate])

    assert diagnostics == [
             %Diagnostic{
               compiler_name: "Surface",
               details: nil,
               file:
                 Path.expand(
                   "test/support/mix/tasks/compile/surface/validate_components_test/live_view_with_external_template.sface"
                 ),
               message: "missing required property \"value\" for component <ComponentCall>",
               position: {1, 2},
               severity: :warning
             }
           ]
  end

  defmodule Recursive do
    use Surface.Component

    prop list, :list, required: true
    data item, :any
    data rest, :list

    def render(%{list: [item | rest]} = assigns) do
      assigns =
        assigns
        |> assign(:item, item)
        |> assign(:rest, rest)

      ~F"""
      {@item}
      <Recursive list={@rest} />
      """
    end

    def render(assigns), do: ~F""
  end

  test "should return diagnostic when missing required prop for recursive component" do
    component =
      quote do
        ~F[<Recursive />]
      end
      |> compile_surface()

    diagnostics = ValidateComponents.validate([component])

    assert diagnostics == [
             %Diagnostic{
               compiler_name: "Surface",
               details: nil,
               file: Path.expand("code"),
               message: "missing required property \"list\" for component <Recursive>",
               position: {0, 2},
               severity: :warning
             }
           ]
  end

  test "should return diagnostic when props are specified multiple times, but accumulate is false" do
    component =
      quote do
        ~F"""
        <RequiredPropTitle
          title="first"
          title="second"
        />
        """
      end
      |> compile_surface()

    diagnostics = ValidateComponents.validate([component])

    assert diagnostics == [
             %Diagnostic{
               compiler_name: "Surface",
               details: nil,
               file: Path.expand("code"),
               message: """
               the prop `title` has been passed multiple times. Considering only the last value.

               Hint: Either remove all redundant definitions or set option `accumulate` to `true`:

               ```
                 prop title, :string, accumulate: true
               ```

               This way the values will be accumulated in a list.
               """,
               position: {3, 11},
               severity: :warning
             }
           ]
  end

  defmodule RootProp do
    use Surface.Component
    prop text, :any, root: true
    def render(assigns), do: ~F[<div />]
  end

  test "should return diagnostic when props are specified multiple times with root prop, but accumulate is false" do
    component =
      quote do
        ~F"""
        <RootProp
          {"first"}
          text="other"
        />
        """
      end
      |> compile_surface()

    diagnostics = ValidateComponents.validate([component])

    assert diagnostics == [
             %Diagnostic{
               compiler_name: "Surface",
               details: nil,
               file: Path.expand("code"),
               message: """
               the prop `text` has been passed multiple times. Considering only the last value.

               Hint: Either specify the `text` via the root property \(`<RootProp { ... }>`\) or \
               explicitly via the text property \(`<RootProp text="...">`\), but not both.
               """,
               position: {3, 11},
               severity: :warning
             }
           ]
  end

  test "should return diagnostic when passing a root prop and the component doesn't have one" do
    component =
      quote do
        ~F[<StringProp {"first"} />]
      end
      |> compile_surface()

    diagnostics = ValidateComponents.validate([component])

    assert diagnostics == [
             %Diagnostic{
               compiler_name: "Surface",
               details: nil,
               file: Path.expand("code"),
               message: """
               no root property defined for component <StringProp>

               Hint: you can declare a root property using option `root: true`
               """,
               position: {0, 14},
               severity: :warning
             }
           ]
  end

  defmodule AccumulateProp do
    use Surface.Component

    prop prop, :string, accumulate: true

    def render(assigns) do
      ~F"""
      <span :for={v <- @prop}>value: {v}</span>
      """
    end
  end

  test "should not return diagnostic when props are specified multiple times, and accumulate is true" do
    component =
      quote do
        ~F"""
        <AccumulateProp
          prop="first"
          prop="second"
        />
        """
      end
      |> compile_surface()

    diagnostics = ValidateComponents.validate([component])
    assert diagnostics == []
  end

  defmodule AccumulateRootProp do
    use Surface.Component
    prop text, :any, root: true, accumulate: true
    def render(assigns), do: ~F[<div />]
  end

  test "should not return diagnostic when props are specified multiple times with root prop, and accumulate is true" do
    component =
      quote do
        ~F"""
        <AccumulateRootProp
          {"first"}
          text="other"
        />
        """
      end
      |> compile_surface()

    diagnostics = ValidateComponents.validate([component])
    assert diagnostics == []
  end
end
