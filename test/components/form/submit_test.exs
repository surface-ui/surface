defmodule Surface.Components.Form.SubmitTest do
  use ExUnit.Case, async: true

  import ComponentTestHelper

  alias Surface.Components.Form.Submit, warn: false

  test "label only" do
    code = """
    <Submit label="Submit" />
    """

    assert render_live(code) =~ """
           <button type="submit">Submit</button>
           """
  end

  test "with class" do
    code = """
    <Submit label="Submit" class="button" />
    """

    assert render_live(code) =~ ~r/class="button"/
  end

  test "with multiple classes" do
    code = """
    <Submit label="Submit" class="button primary" />
    """

    assert render_live(code) =~ ~r/class="button primary"/
  end

  test "with options" do
    code = """
    <Submit label="Submit" class="btn" opts={{ id: "submit-btn" }} />
    """

    assert render_live(code) =~ """
           <button class="btn" id="submit-btn" type="submit">Submit</button>
           """
  end

  test "with children" do
    code = """
    <Submit class="btn">
      <span>Submit</span>
    </Submit>
    """

    assert render_live(code) =~ """
           <button class="btn" type="submit"><span>Submit</span></button>
           """
  end
end
