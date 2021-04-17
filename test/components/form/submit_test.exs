defmodule Surface.Components.Form.SubmitTest do
  use Surface.ConnCase, async: true

  alias Surface.Components.Form.Submit

  test "label only" do
    html =
      render_surface do
        ~H"""
        <Submit label="Submit" />
        """
      end

    assert html =~ """
           <button type="submit">Submit</button>
           """
  end

  test "with class" do
    html =
      render_surface do
        ~H"""
        <Submit label="Submit" class="button" />
        """
      end

    assert html =~ ~r/class="button"/
  end

  test "with multiple classes" do
    html =
      render_surface do
        ~H"""
        <Submit label="Submit" class="button primary" />
        """
      end

    assert html =~ ~r/class="button primary"/
  end

  test "with options" do
    html =
      render_surface do
        ~H"""
        <Submit label="Submit" class="btn" opts={{ id: "submit-btn" }} />
        """
      end

    assert html =~ """
           <button class="btn" id="submit-btn" type="submit">Submit</button>
           """
  end

  test "with children" do
    html =
      render_surface do
        ~H"""
        <Submit class="btn">
          <span>Submit</span>
        </Submit>
        """
      end

    assert html =~ """
           <button class="btn" type="submit">
             <span>Submit</span>
           </button>
           """
  end

  test "events with parent live view as target" do
    html =
      render_surface do
        ~H"""
        <Submit label="Submit"
          capture_click="my_capture_click"
          click="my_click"
          window_focus="my_window_focus"
          window_blur="my_window_blur"
          focus="my_focus"
          blur="my_blur"
          window_keyup="my_window_keyup"
          window_keydown="my_window_keydown"
          keyup="my_keyup"
          keydown="my_keydown"
        />
        """
      end

    assert html =~ ~s(phx-capture-click="my_capture_click")
    assert html =~ ~s(phx-click="my_click")
    assert html =~ ~s(phx-window-focus="my_window_focus")
    assert html =~ ~s(phx-window-blur="my_window_blur")
    assert html =~ ~s(phx-focus="my_focus")
    assert html =~ ~s(phx-blur="my_blur")
    assert html =~ ~s(phx-window-keyup="my_window_keyup")
    assert html =~ ~s(phx-window-keydown="my_window_keydown")
    assert html =~ ~s(phx-keyup="my_keyup")
    assert html =~ ~s(phx-keydown="my_keydown")
  end
end
