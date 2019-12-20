defmodule Surface.PropertiesTest do
  use ExUnit.Case

  test "generate documentation when no @moduledoc is defined" do
    assert get_docs(Surface.PropertiesTest.Components.MyComponent) == """
    Defines a **<MyComponent>** component.

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

  defp get_docs(module) do
    {:docs_v1, _, _, "text/markdown", %{"en" => docs}, %{}, _} = Code.fetch_docs(module)
    docs
  end
end
