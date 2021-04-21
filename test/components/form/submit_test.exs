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
        <Submit label="Submit" click="my_click" />
        """
      end

    assert html =~ ~s(phx-click="my_click")
  end

  test "is compatible with phoenix submit/2" do
    html =
      render_surface do
        ~H"""
        <Submit label="<Submit>" />
        """
      end

    assert html =~
             """
             <button type="submit">
               &lt;Submit&gt;
             </button>
             """

    html =
      render_surface do
        ~H"""
        <Submit>
          {{ "<Submit>" }}
        </Submit>
        """
      end

    assert html =~ """
           <button type="submit">
             &lt;Submit&gt;
           </button>
           """
  end
end
