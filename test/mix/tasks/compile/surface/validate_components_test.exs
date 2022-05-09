defmodule Mix.Tasks.Compile.Surface.ValidateComponentsTest do
  use ExUnit.Case, async: false

  import Surface.LiveViewTest

  alias Mix.Tasks.Compile.Surface.ValidateComponents
  alias Mix.Task.Compiler.Diagnostic

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
               message: "Missing required property \"title\" for component <RequiredPropTitle>",
               position: 0,
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
        ~F[<LiveComponentHasRequiredIdProp />]
      end
      |> compile_surface()

    diagnostics = ValidateComponents.validate([component])

    assert diagnostics == [
             %Mix.Task.Compiler.Diagnostic{
               compiler_name: "Surface",
               details: nil,
               file: Path.expand("code"),
               message: ~S"""
               Missing required property "id" for component <LiveComponentHasRequiredIdProp>

               Hint: Components using `Surface.LiveComponent` automatically define a required `id` prop to make them stateful.
               If you meant to create a stateless component, you can switch to `use Surface.Component`.
               """,
               position: 0,
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
        ~F[<#Macro body="body text" />]
      end
      |> compile_surface()

    diagnostics = ValidateComponents.validate([component])

    assert diagnostics == [
             %Diagnostic{
               compiler_name: "Surface",
               details: nil,
               file: Path.expand("code"),
               message: "Missing required property \"title\" for component <#Macro>",
               position: 0,
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
               message: "Missing required property \"list\" for component <Recursive>",
               position: 0,
               severity: :warning
             }
           ]
  end
end
