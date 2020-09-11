defmodule Surface.Components.Form.InputsTest do
  use ExUnit.Case, async: true

  alias Surface.Components.Form, warn: false
  alias Surface.Components.Form.Inputs, warn: false
  alias Surface.Components.Form.TextInput, warn: false

  import ComponentTestHelper

  test "using generated form received as slot props" do
    code = """
    <Form for={{ :parent }} opts={{ csrf_token: "test" }}>
      <Inputs for={{ :children }} :let={{ form: f }}>
        <TextInput form={{ @f }} field="name" />
        <TextInput form={{ @f }} field="email" />
      </Inputs>
    </Form>
    """

    assert render_live(code) =~ """
           <form action="#" method="post"><input name="_csrf_token" type="hidden" value="test"/>\
           <div>\
           <input id="parent_children_name" name="parent[children][name]" type="text"/>\
           <input id="parent_children_email" name="parent[children][email]" type="text"/>\
           </div>\
           </form>
           """
  end

  test "using generated form stored in the Form context" do
    code = """
    <Form for={{ :parent }} opts={{ csrf_token: "test" }}>
      <Inputs for={{ :children }}>
        <TextInput field="name" />
        <TextInput field="email" />
      </Inputs>
    </Form>
    """

    assert render_live(code) =~ """
           <form action="#" method="post"><input name="_csrf_token" type="hidden" value="test"/>\
           <div>\
           <input id="parent_children_name" name="parent[children][name]" type="text"/>\
           <input id="parent_children_email" name="parent[children][email]" type="text"/>\
           </div>\
           </form>
           """
  end

  test "passing extra opts" do
    code = """
    <Form for={{ :parent }} opts={{ csrf_token: "test" }}>
      <Inputs for={{ :children }} opts={{ as: "custom_name"}}>
        <TextInput field="name" />
        <TextInput field="email" />
      </Inputs>
    </Form>
    """

    assert render_live(code) =~ """
           <form action="#" method="post"><input name="_csrf_token" type="hidden" value="test"/>\
           <div>\
           <input id="parent_children_name" name="custom_name[name]" type="text"/>\
           <input id="parent_children_email" name="custom_name[email]" type="text"/>\
           </div>\
           </form>
           """
  end
end
