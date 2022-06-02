defmodule Surface.ComponentsCallsTest do
  use Surface.ConnCase, async: true

  test "Component has __component_calls__/0" do
    assert Surface.ComponentsCallsTest.Components.ComponentWithExternalTemplate.__components_calls__() == [
             %{
               component: Surface.ComponentsCallsTest.Components.ComponentCall,
               directives: [],
               line: 1,
               node_alias: "ComponentCall",
               props: []
             }
           ]
  end

  test "LiveComponent has __component_calls__/0" do
    assert Surface.ComponentsCallsTest.Components.LiveComponentWithExternalTemplate.__components_calls__() == [
             %{
               component: Surface.ComponentsCallsTest.Components.ComponentCall,
               directives: [],
               line: 1,
               node_alias: "ComponentCall",
               props: []
             }
           ]
  end

  test "LiveView has __component_calls__/0" do
    assert Surface.ComponentsCallsTest.Components.LiveViewWithExternalTemplate.__components_calls__() == [
             %{
               component: Surface.ComponentsCallsTest.Components.ComponentCall,
               directives: [],
               line: 1,
               node_alias: "ComponentCall",
               props: []
             }
           ]
  end
end
