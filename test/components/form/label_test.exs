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
    # test "with block" do
    #   assert safe_to_string(
    #            label do
    #              "Block"
    #            end
    #          ) == ~s(<label>Block</label>)

    #   assert safe_to_string(
    #            label class: "foo" do
    #              "Block"
    #            end
    #          ) == ~s(<label class="foo">Block</label>)
    # end

    test "with field but no content" do
      html = render_surface(do: ~H[<Label form={{ :search }} field={{ :key }} />])
      assert html =~ ~r[<label for="search_key">(.*)Key(.*)</label>]s

      # assert safe_to_string(label(:search, :key, for: "test_key")) ==
      #          ~s(<label for="test_key">Key</label>)

      # assert safe_to_string(label(:search, :key, for: "test_key", class: "foo")) ==
      #          ~s(<label class="foo" for="test_key">Key</label>)
    end

    test "with field and inline content" do
      html = render_surface(do: ~H[<Label form={{ :search }} field={{ :key }}>Search</Label>])
      assert html =~ ~r[<label for="search_key">(.*)Search(.*)</label>]s

      # assert safe_to_string(label(:search, :key, "Search", for: "test_key")) ==
      #          ~s(<label for="test_key">Search</label>)

      # assert safe_form(&label(&1, :key, "Search")) == ~s(<label for="search_key">Search</label>)

      # assert safe_form(&label(&1, :key, "Search", for: "test_key")) ==
      #          ~s(<label for="test_key">Search</label>)

      # assert safe_form(&label(&1, :key, "Search", for: "test_key", class: "foo")) ==
      #          ~s(<label class="foo" for="test_key">Search</label>)
    end

    test "with field and inline safe content" do
      # assert safe_to_string(label(:search, :key, {:safe, "<em>Search</em>"})) ==
      #          ~s(<label for="search_key"><em>Search</em></label>)

      html =
        render_surface do
          ~H"""
          <Label form={{ :search }} field={{ :key }}>
            {{ {:safe, "<em>Search</em>"} }}
          </Label>
          """
        end

      assert html =~ ~r[<label for="search_key">(.*)<em>Search</em>(.*)</label>]s
    end

    # test "with field and block content" do
    #   assert safe_form(&label(&1, :key, do: "Hello")) == ~s(<label for="search_key">Hello</label>)

    #   assert safe_form(&label(&1, :key, [class: "test-label"], do: "Hello")) ==
    #            ~s(<label class="test-label" for="search_key">Hello</label>)
    # end
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
