defmodule Surface.Components.Form.HiddenInputTest do
  use Surface.ConnCase, async: true

  alias Surface.Components.Form.HiddenInput

  test "empty input" do
    html =
      render_surface do
        ~H"""
        <HiddenInput form="user" field="token" />
        """
      end

    assert html =~ """
           <input id="user_token" name="user[token]" type="hidden">
           """
  end

  test "input with atom field" do
    html =
      render_surface do
        ~H"""
        <HiddenInput form="user" field={:token} />
        """
      end

    assert html =~ """
           <input id="user_token" name="user[token]" type="hidden">
           """
  end

  test "setting the value" do
    html =
      render_surface do
        ~H"""
        <HiddenInput form="user" field="token" value="token" />
        """
      end

    assert html =~ """
           <input id="user_token" name="user[token]" type="hidden" value="token">
           """
  end

  test "setting the class" do
    html =
      render_surface do
        ~H"""
        <HiddenInput form="user" field="token" class="input" />
        """
      end

    assert html =~ ~r/class="input"/
  end

  test "setting multiple classes" do
    html =
      render_surface do
        ~H"""
        <HiddenInput form="user" field="token" class="input primary" />
        """
      end

    assert html =~ ~r/class="input primary"/
  end

  test "passing other options" do
    html =
      render_surface do
        ~H"""
        <HiddenInput form="user" field="token" opts={autofocus: "autofocus"} />
        """
      end

    assert html =~ """
           <input autofocus="autofocus" id="user_token" name="user[token]" type="hidden">
           """
  end

  test "events with parent live view as target" do
    html =
      render_surface do
        ~H"""
        <HiddenInput form="user" field="color" value="token" click="my_click" />
        """
      end

    assert html =~ ~s(phx-click="my_click")
  end

  test "setting id and name through props" do
    html =
      render_surface do
        ~H"""
        <HiddenInput form="user" field="pass" id="token" name="token" />
        """
      end

    assert html =~ """
           <input id="token" name="token" type="hidden">
           """
  end
end
