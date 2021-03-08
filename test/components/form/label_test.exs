defmodule Surface.Components.Form.LabelTest do
  use Surface.ConnCase, async: true

  alias Surface.Components.Form
  alias Surface.Components.Form.{Field, Label}

  test "generates a <label> passing any opts to the underlying html element" do
    html =
      render_surface do
        ~H"""
        <Label opts={{ id: "my_id" }}/>
        """
      end

    assert html =~ ~r[<label id="my_id">(.+)</label>]s
  end

  test "property class" do
    html =
      render_surface do
        ~H"""
        <Label class={{ :label }}/>
        """
      end

    assert html =~ ~S(class="label")
  end

  test "property multiple classes" do
    html =
      render_surface do
        ~H"""
        <Label class={{ :label, :primary }}/>
        """
      end

    assert html =~ ~S(class="label primary")
  end

  test "properties form and field" do
    html =
      render_surface do
        ~H"""
        <Label form="user" field="name"/>
        """
      end

    assert html =~ ~r[<label for="user_name">(.+)</label>]s
  end

  test "use context's form and field by default" do
    html =
      render_surface do
        ~H"""
        <Form for={{ :user }}>
          <Field name="name">
            <Label/>
          </Field>
        </Form>
        """
      end

    assert html =~ ~r[<label for="user_name">(.+)</label>]s
  end

  describe "is compatible with phoenix label/2" do
    test "with block" do
      html = render_surface(do: ~H[<Label>Block</Label>])
      assert html =~ ~r[<label>(.*)Block(.*)</label>]s

      html = render_surface(do: ~H[<Label class="foo">Block</Label>])
      assert html =~ ~r[<label class="foo">(.*)Block(.*)</label>]s
    end

    test "with field but no content" do
      html = render_surface(do: ~H[<Label form={{ :search }} field={{ :key }} />])
      assert html =~ ~r[<label for="search_key">(.*)Key(.*)</label>]s

      html =
        render_surface(
          do: ~H[<Label form={{ :search }} field={{ :key }} opts={{ for: "test_key" }} />]
        )

      assert html =~ ~r[<label for="test_key">(.*)Key(.*)</label>]s

      html =
        render_surface(
          do:
            ~H[<Label form={{ :search }} field={{ :key }} class="foo" opts={{ for: "test_key" }} />]
        )

      assert html =~ ~r[<label class="foo" for="test_key">(.*)Key(.*)</label>]s
    end

    test "with field and inline content" do
      html = render_surface(do: ~H[<Label text="Search" form={{ :search }} field={{ :key }} />])
      assert html =~ ~r[<label for="search_key">(.*)Search(.*)</label>]s

      html =
        render_surface(
          do:
            ~H[<Label text="Search" form={{ :search }} field={{ :key }} opts={{ for: "test_key" }} />]
        )

      assert html =~ ~r[<label for="test_key">(.*)Search(.*)</label>]s

      html =
        render_surface do
          ~H"""
          <Form for={{ :search }}>
            <Field name="key">
              <Label text="Search" />
            </Field>
          </Form>
          """
        end

      assert html =~ ~r[<label for="search_key">(.+)Search(.*)</label>]s

      html =
        render_surface do
          ~H"""
          <Form for={{ :search }}>
            <Field name="key">
              <Label text="Search" opts={{ for: "test_key" }} />
            </Field>
          </Form>
          """
        end

      assert html =~ ~r[<label for="test_key">(.+)Search(.*)</label>]s

      html =
        render_surface do
          ~H"""
          <Form for={{ :search }}>
            <Field name="key">
              <Label text="Search" class="foo" opts={{ for: "test_key" }} />
            </Field>
          </Form>
          """
        end

      assert html =~ ~r[<label class="foo" for="test_key">(.+)Search(.*)</label>]s
    end

    test "with field and inline safe content" do
      html =
        render_surface(
          do:
            ~H[<Label text={{ {:safe, "<em>Search</em>"} }} form={{ :search }} field={{ :key }} />]
        )

      assert html =~ ~r[<label for="search_key">(.*)<em>Search</em>(.*)</label>]s
    end

    test "with field and block content" do
      html =
        render_surface do
          ~H"""
          <Form for={{ :search }}>
            <Field name="key">
              <Label>Hello</Label>
            </Field>
          </Form>
          """
        end

      assert html =~ ~r[<label for="search_key">(.+)Hello(.*)</label>]s

      html =
        render_surface do
          ~H"""
          <Form for={{ :search }}>
            <Field name="key">
              <Label class="test-label">Hello</Label>
            </Field>
          </Form>
          """
        end

      assert html =~ ~r[<label class="test-label" for="search_key">(.+)Hello(.*)</label>]s
    end
  end
end

defmodule Surface.Components.Form.LabelConfigTest do
  use Surface.ConnCase

  alias Surface.Components.Form.Label

  test ":default_class config" do
    using_config Label, default_class: "default_class" do
      html =
        render_surface do
          ~H"""
          <Label/>
          """
        end

      assert html =~ ~r/class="default_class"/
    end
  end
end
