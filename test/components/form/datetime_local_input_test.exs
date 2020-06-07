defmodule Surface.Components.Form.DateTimeLocalInputTest do
  use ExUnit.Case, async: true

  alias Surface.Components.Form.DateTimeLocalInput, warn: false

  import ComponentTestHelper

  test "empty input" do
    code = """
    <DateTimeLocalInput form="order" field="completed_at" />
    """

    assert render_live(code) =~ """
           <input id="order_completed_at" name="order[completed_at]" type="datetime-local"/>
           """
  end

  test "setting the value" do
    code = """
    <DateTimeLocalInput form="order" field="completed_at" value="2020-05-05T19:30" />
    """

    assert render_live(code) =~ """
           <input id="order_completed_at" name="order[completed_at]" type="datetime-local" value="2020-05-05T19:30"/>
           """
  end

  test "setting the class" do
    code = """
    <DateTimeLocalInput class="my_class"/>
    """

    assert render_live(code) =~ ~r/class="my_class"/
  end

  test "passing other options" do
    code = """
    <DateTimeLocalInput form="order" field="completed_at" opts={{ id: "myid", autofocus: "autofocus" }} />
    """

    assert render_live(code) =~ """
           <input autofocus="autofocus" id="myid" name="order[completed_at]" type="datetime-local"/>
           """
  end

  test "blur event with parent live view as target" do
    code = """
    <DateTimeLocalInput form="order" field="completed_at" value="2020-05-05T19:30" blur="my_blur" />
    """

    assert render_live(code) =~ """
           <input id="order_completed_at" name="order[completed_at]" phx-blur="my_blur" type="datetime-local" value="2020-05-05T19:30"/>
           """
  end

  test "focus event with parent live view as target" do
    code = """
    <DateTimeLocalInput form="order" field="completed_at" value="2020-05-05T19:30" focus="my_focus" />
    """

    assert render_live(code) =~ """
           <input id="order_completed_at" name="order[completed_at]" phx-focus="my_focus" type="datetime-local" value="2020-05-05T19:30"/>
           """
  end

  test "capture click event with parent live view as target" do
    code = """
    <DateTimeLocalInput form="order" field="completed_at" value="2020-05-05T19:30" capture_click="my_click" />
    """

    assert render_live(code) =~ """
           <input id="order_completed_at" name="order[completed_at]" phx-capture-click="my_click" type="datetime-local" value="2020-05-05T19:30"/>
           """
  end

  test "keydown event with parent live view as target" do
    code = """
    <DateTimeLocalInput form="order" field="completed_at" value="2020-05-05T19:30" keydown="my_keydown" />
    """

    assert render_live(code) =~ """
           <input id="order_completed_at" name="order[completed_at]" phx-keydown="my_keydown" type="datetime-local" value="2020-05-05T19:30"/>
           """
  end

  test "keyup event with parent live view as target" do
    code = """
    <DateTimeLocalInput form="order" field="completed_at" value="2020-05-05T19:30" keyup="my_keyup" />
    """

    assert render_live(code) =~ """
           <input id="order_completed_at" name="order[completed_at]" phx-keyup="my_keyup" type="datetime-local" value="2020-05-05T19:30"/>
           """
  end
end

defmodule Surface.Components.Form.DateTimeLocalInputConfigTest do
  use ExUnit.Case

  alias Surface.Components.Form.DateTimeLocalInput, warn: false
  import ComponentTestHelper

  test ":default_class config" do
    using_config DateTimeLocalInput, default_class: "default_class" do
      code = """
      <DateTimeLocalInput/>
      """

      assert render_live(code) =~ ~r/class="default_class"/
    end
  end
end
