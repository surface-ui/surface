defmodule Surface.Components.Form.TextAreaTest do
  use Surface.ConnCase, async: true

  alias Surface.Components.Form.TextArea

  test "empty textarea" do
    html =
      render_surface do
        ~F"""
        <TextArea form="user" field="summary" />
        """
      end

    assert html =~ """
           <textarea id="user_summary" name="user[summary]">
           </textarea>
           """
  end

  test "textarea with atom field" do
    html =
      render_surface do
        ~F"""
        <TextArea form="user" field={:summary} />
        """
      end

    assert html =~ """
           <textarea id="user_summary" name="user[summary]">
           </textarea>
           """
  end

  test "setting the value" do
    html =
      render_surface do
        ~F"""
        <TextArea form="user" field="summary" value="some content" />
        """
      end

    assert html =~ """
           <textarea id="user_summary" name="user[summary]">
           some content</textarea>
           """
  end

  test "setting the class" do
    html =
      render_surface do
        ~F"""
        <TextArea form="user" field="summary" class="input" />
        """
      end

    assert html =~ ~r/class="input"/
  end

  test "setting multiple classes" do
    html =
      render_surface do
        ~F"""
        <TextArea form="user" field="summary" class="input primary" />
        """
      end

    assert html =~ ~r/class="input primary"/
  end

  test "setting the placeholder" do
    html =
      render_surface do
        ~F"""
        <TextArea form="user" field="summary" placeholder="placeholder-text" />
        """
      end

    assert html =~ ~r/placeholder="placeholder-text"/
  end

  test "passing other options" do
    html =
      render_surface do
        ~F"""
        <TextArea form="user" field="summary" opts={autofocus: "autofocus"} />
        """
      end

    assert html =~ """
           <textarea autofocus="autofocus" id="user_summary" name="user[summary]">
           </textarea>
           """
  end

  test "events with parent live view as target" do
    html =
      render_surface do
        ~F"""
        <TextArea form="user" field="summary" click="my_click" />
        """
      end

    assert html =~ ~s(phx-click="my_click")
  end

  test "setting id and name through props" do
    html =
      render_surface do
        ~F"""
        <TextArea form="user" field="summary" id="blog_summary" name="blog_summary" />
        """
      end

    assert html =~ """
           <textarea id="blog_summary" name="blog_summary">
           </textarea>
           """
  end

  test "setting the phx-value-* values" do
    html =
      render_surface do
        ~F"""
        <TextArea form="user" field="summary" values={a: "one", b: :two, c: 3} />
        """
      end

    assert html =~ """
           <textarea id="user_summary" name="user[summary]" phx-value-a="one" phx-value-b="two" phx-value-c="3">
           </textarea>
           """
  end
end

defmodule Surface.Components.Form.TextAreaConfigTest do
  use Surface.ConnCase

  alias Surface.Components.Form.Input
  alias Surface.Components.Form.TextArea

  test ":default_class config" do
    using_config TextArea, default_class: "default_class" do
      html =
        render_surface do
          ~F"""
          <TextArea/>
          """
        end

      assert html =~ ~r/class="default_class"/
    end
  end

  test "component inherits :default_class from Form.Input" do
    using_config Input, default_class: "inherited_default_class" do
      html =
        render_surface do
          ~F"""
          <TextArea/>
          """
        end

      assert html =~ ~r/class="inherited_default_class"/
    end
  end

  test ":default_class config overrides inherited :default_class from Form.Input" do
    using_config Input, default_class: "inherited_default_class" do
      using_config TextArea, default_class: "default_class" do
        html =
          render_surface do
            ~F"""
            <TextArea/>
            """
          end

        assert html =~ ~r/class="default_class"/
      end
    end
  end
end
