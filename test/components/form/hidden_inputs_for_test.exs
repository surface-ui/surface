defmodule Surface.Components.Form.HiddenInputsTest do
  use ExUnit.Case, async: true

  alias Surface.Components.Form, warn: false
  alias Surface.Components.Form.Inputs, warn: false
  alias Surface.Components.Form.HiddenInputs, warn: false

  import ComponentTestHelper

  test "using generated form received as slot props" do
    code = """
    <Form for={{ :parent }} opts={{ csrf_token: "test" }}>
      <Inputs for={{ :children }} :let={{ form: f }}>
        <HiddenInputs for={{ f }} />
      </Inputs>
    </Form>
    """

    assert render_live(code) =~ """
           <form action="#" method="post">\
           <input name="_csrf_token" type="hidden" value="test"/>\
           </form>
           """
  end

  test "using generated form stored in the Form context" do
    code = """
    <Form for={{ :parent }} opts={{ csrf_token: "test" }}>
      <Inputs for={{ :children }}>
        <HiddenInputs />
      </Inputs>
    </Form>
    """

    assert render_live(code) =~ """
           <form action="#" method="post">\
           <input name="_csrf_token" type="hidden" value="test"/>\
           </form>
           """
  end
end
