defmodule Mix.Tasks.Compile.Surface.ValidateComponentsTest do
  use ExUnit.Case, async: false

  alias Mix.Tasks.Compile.Surface.ValidateComponents
  alias Mix.Task.Compiler.Diagnostic

  defmodule RequiredPropTitle do
    use Surface.Component
    prop title, :string, required: true
    def render(assigns), do: ~F"{@title}"
  end

  defmodule MissingRequiredProp do
    use Surface.Component

    def line, do: __ENV__.line + 4

    def render(assigns) do
      ~F"""
      <RequiredPropTitle />
      """
    end
  end

  test "should return diagnostic when missing required prop" do
    diagnostics = ValidateComponents.validate([MissingRequiredProp])
    file = to_string(MissingRequiredProp.module_info(:compile)[:source])

    assert diagnostics == [
             %Diagnostic{
               compiler_name: "Surface",
               details: nil,
               file: file,
               message: "Missing required property \"title\" for component <RequiredPropTitle>",
               position: MissingRequiredProp.line(),
               severity: :error
             }
           ]
  end

  defmodule PropsDirective do
    use Surface.Component

    def render(assigns) do
      ~F"""
      <RequiredPropTitle :props={%{}}/>
      <RequiredPropTitle {...%{}} />
      """
    end
  end

  test "should not return diagnostic when :props directive is present" do
    diagnostics = ValidateComponents.validate([PropsDirective])
    assert diagnostics == []
  end

  defmodule LiveComponentHasRequiredIdProp do
    use Surface.LiveComponent
    def render(assigns), do: ~F"<div />"
  end

  defmodule MissingIdForLiveComponent do
    use Surface.Component

    def line, do: __ENV__.line + 4

    def render(assigns) do
      ~F"""
      <LiveComponentHasRequiredIdProp />
      """
    end
  end

  test "should return diagnostic when missing automatically define id prop for LiveComponent" do
    diagnostics = ValidateComponents.validate([MissingIdForLiveComponent])
    file = to_string(MissingIdForLiveComponent.module_info(:compile)[:source])

    assert diagnostics == [
             %Mix.Task.Compiler.Diagnostic{
               compiler_name: "Surface",
               details: nil,
               file: file,
               message: ~S"""
               Missing required property "id" for component <LiveComponentHasRequiredIdProp>

               Hint: Components using `Surface.LiveComponent` automatically define a required `id` prop to make them stateful.
               If you meant to create a stateless component, you can switch to `use Surface.Component`.
               """,
               position: MissingIdForLiveComponent.line(),
               severity: :error
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

  defmodule MissingRequiredPropForMacro do
    use Surface.Component

    alias MacroWithRequiredPropTitle, as: Macro
    def line, do: __ENV__.line + 4

    def render(assigns) do
      ~F"""
      <#Macro body="body text" />
      """
    end
  end

  test "should return diagnostic when missing required prop for macro component" do
    diagnostics = ValidateComponents.validate([MissingRequiredPropForMacro])
    file = to_string(MissingRequiredPropForMacro.module_info(:compile)[:source])

    assert diagnostics == [
             %Diagnostic{
               compiler_name: "Surface",
               details: nil,
               file: file,
               message: "Missing required property \"title\" for component <#Macro>",
               position: MissingRequiredPropForMacro.line(),
               severity: :error
             }
           ]
  end

  defmodule PassingRequiredPropForMacro do
    use Surface.Component

    alias MacroWithRequiredPropTitle, as: Macro
    def line, do: __ENV__.line + 4

    def render(assigns) do
      ~F"""
      <#Macro title="title text" body="body text" />
      """
    end
  end

  test "should not return diagnostic when required prop is passed to macro component" do
    diagnostics = ValidateComponents.validate([PassingRequiredPropForMacro])
    assert diagnostics == []
  end

  defmodule Recursive do
    use Surface.Component

    prop list, :list, required: true

    def render(%{list: [item | rest]} = assigns) do
      ~F"""
      {item}
      <Recursive list={rest} />
      """
    end

    def render(assigns), do: ~F""
  end

  defmodule MissingRequiredPropForRecursiveComponent do
    use Surface.Component

    def line, do: __ENV__.line + 4

    def render(assigns) do
      ~F"""
      <Recursive />
      """
    end
  end

  test "should return diagnostic when missing required prop for recursive component" do
    diagnostics = ValidateComponents.validate([MissingRequiredPropForRecursiveComponent])
    file = to_string(MissingRequiredPropForRecursiveComponent.module_info(:compile)[:source])

    assert diagnostics == [
             %Diagnostic{
               compiler_name: "Surface",
               details: nil,
               file: file,
               message: "Missing required property \"list\" for component <Recursive>",
               position: MissingRequiredPropForRecursiveComponent.line(),
               severity: :error
             }
           ]
  end
end
