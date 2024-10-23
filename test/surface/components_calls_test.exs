defmodule Surface.ComponentsCallsTest do
  use Surface.ConnCase, async: true

  describe "__component_calls__/0" do
    test "on Component" do
      assert [
               %{
                 component: Surface.Components.Raw,
                 directives: [],
                 line: 2,
                 column: 4,
                 node_alias: "#Raw",
                 props: [],
                 dep_type: :compile,
                 file: file
               },
               %{
                 component: Surface.ComponentsCallsTest.Components.ComponentCall,
                 directives: [],
                 line: 1,
                 column: 2,
                 node_alias: "ComponentCall",
                 props: [],
                 dep_type: :export,
                 file: file
               }
             ] = Surface.ComponentsCallsTest.Components.ComponentWithExternalTemplate.__components_calls__()

      assert file =~ "test/support/components_calls_test/component_with_external_template.sface"
    end

    test "on LiveComponent" do
      assert [
               %{
                 component: Surface.ComponentsCallsTest.Components.ComponentCall,
                 directives: [],
                 line: 1,
                 column: 2,
                 node_alias: "ComponentCall",
                 props: [],
                 dep_type: :export,
                 file: file
               }
             ] = Surface.ComponentsCallsTest.Components.LiveComponentWithExternalTemplate.__components_calls__()

      assert file =~ "test/support/components_calls_test/live_component_with_external_template.sface"
    end

    test "on LiveView" do
      assert [
               %{
                 component: Surface.ComponentsCallsTest.Components.ComponentCall,
                 directives: [],
                 line: 1,
                 column: 2,
                 node_alias: "ComponentCall",
                 props: [],
                 dep_type: :export,
                 file: file
               }
             ] = Surface.ComponentsCallsTest.Components.LiveViewWithExternalTemplate.__components_calls__()

      assert file =~ "test/support/components_calls_test/live_view_with_external_template.sface"
    end
  end

  describe "define __surface_sig_xxxxxx_/0 to trigger dependents recompilation" do
    defmodule ComponentSignature do
      use Surface.Component

      def render(assigns), do: ~F[<div></div>]
    end

    defmodule LiveComponentSignature do
      use Surface.LiveComponent

      def render(assigns), do: ~F[<div></div>]
    end

    defmodule ComponentSignatureWithProps do
      use Surface.Component

      prop prop1, :string
      prop prop2, :string

      def render(assigns), do: ~F[<div></div>]
    end

    defmodule ComponentSignatureWithPropsAndOptions do
      use Surface.Component

      prop prop1, :string, required: true
      prop prop2, :string

      def render(assigns), do: ~F[<div></div>]
    end

    defmodule ComponentSignatureWithWithPropsAndSlots do
      use Surface.Component

      prop prop1, :string
      prop prop2, :string
      slot slot1
      slot slot2

      def render(assigns), do: ~F[<div></div>]
    end

    defmodule ComponentSignatureWithPropsAndSlotName do
      use Surface.Component, slot: "col"

      prop prop1, :string
      prop prop2, :string

      def render(assigns), do: ~F[<div></div>]
    end

    defmodule ComponentSignatureWithPropsAndDifferentRender do
      use Surface.Component

      prop prop1, :string
      prop prop2, :string

      def render(assigns), do: ~F[<div>I'm different</div>]
    end

    defmodule ComponentSignatureWithWithPropsAndSlotsReversed do
      use Surface.Component

      slot slot2
      slot slot1
      prop prop2, :string
      prop prop1, :string

      def render(assigns), do: ~F[<div></div>]
    end

    test "gererate signature function" do
      sig_func = ComponentSignature.__surface_sig__()
      assert function_exported?(ComponentSignature, sig_func, 0)
    end

    test "the type of component changes the signature" do
      assert ComponentSignature.__surface_sig__() !=
               LiveComponentSignature.__surface_sig__()
    end

    test "props change the signature" do
      assert ComponentSignature.__surface_sig__() !=
               ComponentSignatureWithProps.__surface_sig__()
    end

    test "options change the signature" do
      assert ComponentSignatureWithProps.__surface_sig__() !=
               ComponentSignatureWithPropsAndOptions.__surface_sig__()
    end

    test "slots change the signature" do
      assert ComponentSignatureWithProps.__surface_sig__() !=
               ComponentSignatureWithWithPropsAndSlots.__surface_sig__()
    end

    test "the slot name changes the signature (slotable component)" do
      assert ComponentSignatureWithProps.__surface_sig__() !=
               ComponentSignatureWithPropsAndSlotName.__surface_sig__()
    end

    test "the order of props and slots is ignored so it doesn't change the signature" do
      assert ComponentSignatureWithWithPropsAndSlots.__surface_sig__() ==
               ComponentSignatureWithWithPropsAndSlotsReversed.__surface_sig__()
    end

    test "changes inside any function (including render/1) don't change the signature" do
      assert ComponentSignatureWithProps.__surface_sig__() ==
               ComponentSignatureWithPropsAndDifferentRender.__surface_sig__()
    end
  end
end
