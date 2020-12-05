defmodule Surface.Components.Form.TextInputTest do
  use Surface.ConnCase, async: true

  import ComponentTestHelper
  alias Surface.Components.Form.TextInput

  test "empty input" do
    html = render_surface_component(TextInput, form: :user, field: :name)

    assert html =~ """
           <input id="user_name" name="user[name]" type="text">
           """
  end

  test "setting the value" do
    html = render_surface_component(TextInput, form: :user, field: :name, value: "Max")

    assert html =~ """
           <input id="user_name" name="user[name]" type="text" value="Max">
           """
  end

  test "setting the class" do
    html = render_surface_component(TextInput, form: :user, field: :name, class: ["input"])

    assert html =~ ~r/class="input"/
  end

  test "setting multiple classes" do
    html =
      render_surface_component(TextInput, form: :user, field: :name, class: ["input", "primary"])

    assert html =~ ~r/class="input primary"/
  end

  test "passing other options" do
    html =
      render_surface_component(TextInput,
        form: :user,
        field: :name,
        opts: [autofocus: "autofocus"]
      )

    assert html =~ """
           <input autofocus="autofocus" id="user_name" name="user[name]" type="text">
           """
  end

  test "blur event with parent live view as target" do
    html =
      render_surface_component(
        TextInput,
        form: :user,
        field: :color,
        value: "Max",
        blur: %{name: "my_blur", target: :live_view}
      )

    assert html =~ """
           <input id="user_color" name="user[color]" phx-blur="my_blur" type="text" value="Max">
           """
  end

  test "focus event with parent live view as target" do
    html =
      render_surface_component(
        TextInput,
        form: :user,
        field: :color,
        value: "Max",
        focus: %{name: "my_focus", target: :live_view}
      )

    assert html =~ """
           <input id="user_color" name="user[color]" phx-focus="my_focus" type="text" value="Max">
           """
  end

  test "capture click event with parent live view as target" do
    html =
      render_surface_component(TextInput,
        form: :user,
        field: :color,
        value: "Max",
        capture_click: %{name: "my_click", target: :live_view}
      )

    assert html =~ """
           <input id="user_color" name="user[color]" phx-capture-click="my_click" type="text" value="Max">
           """
  end

  test "keydown event with parent live view as target" do
    html =
      render_surface_component(TextInput,
        form: :user,
        field: :color,
        value: "Max",
        keydown: %{name: "my_keydown", target: :live_view}
      )

    assert html =~ """
           <input id="user_color" name="user[color]" phx-keydown="my_keydown" type="text" value="Max">
           """
  end

  test "keyup event with parent live view as target" do
    html =
      render_surface_component(TextInput,
        form: :user,
        field: :color,
        value: "Max",
        keyup: %{name: "my_keyup", target: :live_view}
      )

    assert html =~ """
           <input id="user_color" name="user[color]" phx-keyup="my_keyup" type="text" value="Max">
           """
  end

  test "setting id and name through props" do
    html =
      render_surface_component(TextInput,
        form: :user,
        field: :name,
        id: "username",
        name: "username"
      )

    assert html =~ """
           <input id="username" name="username" type="text">
           """
  end
end

defmodule Surface.Components.Form.TextInputConfigTest do
  use ExUnit.Case

  import ComponentTestHelper
  alias Surface.Components.Form.TextInput, warn: false

  test ":default_class config" do
    using_config TextInput, default_class: "default_class" do
      code =
        quote do
          ~H"""
          <TextInput/>
          """
        end

      assert render_live(code) =~ ~r/class="default_class"/
    end
  end
end
