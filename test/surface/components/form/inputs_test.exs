defmodule Surface.Components.Form.InputsTest do
  use Surface.ConnCase, async: true

  alias Surface.Components.Form
  alias Surface.Components.Form.Field
  alias Surface.Components.Form.Inputs
  alias Surface.Components.Form.TextInput
  alias Surface.Schemas.Parent

  test "using generated form received as slot arg" do
    html =
      render_surface do
        ~F"""
        <Form for={%{}} as={:parent} opts={csrf_token: "test"}>
          <Inputs for={:children} :let={form: f}>
            <TextInput form={f} field="name" />
            <TextInput form={f} field="email" />
          </Inputs>
        </Form>
        """
      end

    assert html =~ """
           <form action="#" method="post">
               <input name="_csrf_token" type="hidden" hidden value="test">
                 <input type="hidden" name="parent[children][_persistent_id]" value="0">
               <input id="parent_children_0_name" name="parent[children][name]" type="text">
               <input id="parent_children_0_email" name="parent[children][email]" type="text">
           </form>
           """
  end

  test "if the index is received as a slot arg" do
    html =
      render_surface do
        ~F"""
        <Form for={Parent.changeset(%{children: [%{name: "first"}, %{name: "second"}]})} as={:cs} opts={csrf_token: "test"}>
          <Inputs for={:children} :let={index: idx}>
            <div>index: <span>{idx}</span></div>
          </Inputs>
        </Form>
        """
      end

    assert html =~ """
           <form action="#" method="post">
               <input name="_csrf_token" type="hidden" hidden value="test">
                 <input type="hidden" name="cs[children][0][_persistent_id]" value="0">
               <div>index: <span>0</span></div>
                 <input type="hidden" name="cs[children][1][_persistent_id]" value="1">
               <div>index: <span>1</span></div>
           </form>
           """
  end

  test "using generated form stored in the Form context" do
    html =
      render_surface do
        ~F"""
        <Form for={%{}} as={:parent} opts={csrf_token: "test"}>
          <Inputs for={:children}>
            <TextInput field="name" />
            <TextInput field="email" />
          </Inputs>
        </Form>
        """
      end

    assert html =~ """
           <form action="#" method="post">
               <input name="_csrf_token" type="hidden" hidden value="test">
                 <input type="hidden" name="parent[children][_persistent_id]" value="0">
               <input id="parent_children_0_name" name="parent[children][name]" type="text">
               <input id="parent_children_0_email" name="parent[children][email]" type="text">
           </form>
           """
  end

  test "passing extra opts" do
    html =
      render_surface do
        ~F"""
        <Form for={%{}} as={:parent} opts={csrf_token: "test"}>
          <Inputs for={:children} opts={as: "custom_name"}>
            <TextInput field="name" />
            <TextInput field="email" />
          </Inputs>
        </Form>
        """
      end

    assert html =~ """
           <form action="#" method="post">
               <input name="_csrf_token" type="hidden" hidden value="test">
                 <input type="hidden" name="custom_name[_persistent_id]" value="0">
               <input id="parent_children_0_name" name="custom_name[name]" type="text">
               <input id="parent_children_0_email" name="custom_name[email]" type="text">
           </form>
           """
  end

  test "using generated field stored in the Field context" do
    html =
      render_surface do
        ~F"""
        <Form for={%{}} as={:parent} opts={csrf_token: "test"}>
          <Field name={:children}>
            <Inputs>
              <TextInput field="name" />
              <TextInput field="email" />
            </Inputs>
          </Field>
        </Form>
        """
      end

    assert html =~ """
           <form action="#" method="post">
               <input name="_csrf_token" type="hidden" hidden value="test">
             <div>
                 <input type="hidden" name="parent[children][_persistent_id]" value="0">
                 <input id="parent_children_0_name" name="parent[children][name]" type="text">
                 <input id="parent_children_0_email" name="parent[children][email]" type="text">
           </div>
           </form>
           """
  end

  test "property for as string" do
    html =
      render_surface do
        ~F"""
        <Form for={%{}} as={:parent} opts={csrf_token: "test"}>
          <Inputs for="children">
            <TextInput field="name" />
            <TextInput field="email" />
          </Inputs>
        </Form>
        """
      end

    assert html =~ """
           <form action="#" method="post">
               <input name="_csrf_token" type="hidden" hidden value="test">
                 <input type="hidden" name="parent[children][_persistent_id]" value="0">
               <input id="parent_children_0_name" name="parent[children][name]" type="text">
               <input id="parent_children_0_email" name="parent[children][email]" type="text">
           </form>
           """
  end
end
