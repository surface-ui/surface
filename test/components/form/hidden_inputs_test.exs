defmodule Surface.Components.Form.HiddenInputsTest do
  use Surface.ConnCase, async: true

  alias Surface.Components.Form
  alias Surface.Components.Form.Inputs
  alias Surface.Components.Form.HiddenInputs

  test "using generated form received as slot props" do
    html =
      render_surface do
        ~F"""
        <Form for={:parent} opts={csrf_token: "test"}>
          <Inputs for={:children} :let={form: f}>
            <HiddenInputs for={f} />
          </Inputs>
        </Form>
        """
      end

    assert html =~ """
           <form action="#" method="post">\
           <input name="_csrf_token" type="hidden" value="test">
           </form>
           """
  end

  test "using generated form stored in the Form context" do
    html =
      render_surface do
        ~F"""
        <Form for={:parent} opts={csrf_token: "test"}>
          <Inputs for={:children}>
            <HiddenInputs />
          </Inputs>
        </Form>
        """
      end

    assert html =~ """
           <form action="#" method="post">\
           <input name="_csrf_token" type="hidden" value="test">
           </form>
           """
  end
end
