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

  test "blur event with parent live view as target" do
    html =
      render_surface do
        ~H"""
        <Submit label="Submit" blur="my_blur" />
        """
      end

    assert html =~ """
           <button phx-blur="my_blur" type="submit">Submit</button>
           """
  end

  test "focus event with parent live view as target" do
    html =
      render_surface do
        ~H"""
        <Submit label="Submit" focus="my_focus" />
        """
      end

    assert html =~ """
           <button phx-focus="my_focus" type="submit">Submit</button>
           """
  end

  test "capture click event with parent live view as target" do
    html =
      render_surface do
        ~H"""
        <Submit label="Submit" capture_click="my_click" />
        """
      end

    assert html =~ """
           <button phx-capture-click="my_click" type="submit">Submit</button>
           """
  end

  test "keydown event with parent live view as target" do
    html =
      render_surface do
        ~H"""
        <Submit label="Submit" keydown="my_keydown" />
        """
      end

    assert html =~ """
           <button phx-keydown="my_keydown" type="submit">Submit</button>
           """
  end

  test "keyup event with parent live view as target" do
    html =
      render_surface do
        ~H"""
        <Submit label="Submit" keyup="my_keyup" />
        """
      end

    assert html =~ """
           <button phx-keyup="my_keyup" type="submit">Submit</button>
           """
  end
end
