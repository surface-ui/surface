defmodule Surface.Components.Form.HiddenInputsTest do
  use Surface.ConnCase, async: true

  alias Surface.Components.Form
  alias Surface.Components.Form.Inputs
  alias Surface.Components.Form.HiddenInputs
  alias Surface.Schemas.Parent

  test "using generated form received as slot arg" do
    html =
      render_surface do
        ~F"""
        <Form for={%{}} as={:parent} opts={csrf_token: "test"}>
          <Inputs for={:children} :let={form: f}>
            <HiddenInputs for={f} />
          </Inputs>
        </Form>
        """
      end

    assert html =~
             """
             <form action="#" method="post">
                 <input name="_csrf_token" type="hidden" hidden value="test">
                   <input type="hidden" name="parent[children][_persistent_id]" value="0">
               <input type="hidden" name="parent[children][_persistent_id]" value="0">
             </form>
             """
  end

  test "using generated form stored in the Form context" do
    html =
      render_surface do
        ~F"""
        <Form for={%{}} as={:parent} opts={csrf_token: "test"}>
          <Inputs for={:children}>
            <HiddenInputs />
          </Inputs>
        </Form>
        """
      end

    assert html =~
             """
             <form action="#" method="post">
                 <input name="_csrf_token" type="hidden" hidden value="test">
                   <input type="hidden" name="parent[children][_persistent_id]" value="0">
               <input type="hidden" name="parent[children][_persistent_id]" value="0">
             </form>
             """
  end

  test "based on a changeset" do
    cs = Parent.changeset(%{children: [%{name: "first"}]})

    html =
      render_surface do
        ~F"""
        <Form for={cs} as={:parent} opts={csrf_token: "test"}>
          <Inputs for={:children} :let={form: f}>
            <HiddenInputs for={f} />
          </Inputs>
        </Form>
        """
      end

    assert html =~
             """
             <form action="#" method="post">
                 <input name="_csrf_token" type="hidden" hidden value="test">
                   <input type="hidden" name="parent[children][0][_persistent_id]" value="0">
               <input type="hidden" name="parent[children][0][_persistent_id]" value="0">
             </form>
             """
  end
end
