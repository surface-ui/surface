defmodule Surface.Components.Form.RangeInputTest do
  use Surface.ConnCase, async: true

  alias Surface.Components.Form.RangeInput

  test "empty input" do
    html =
      render_surface do
        ~F"""
        <RangeInput form="volume" field="percent" />
        """
      end

    assert html =~ """
           <input id="volume_percent" name="volume[percent]" type="range">
           """
  end

  test "input with atom field" do
    html =
      render_surface do
        ~F"""
        <RangeInput form="volume" field={:percent} />
        """
      end

    assert html =~ """
           <input id="volume_percent" name="volume[percent]" type="range">
           """
  end

  test "setting min, max and step" do
    html =
      render_surface do
        ~F"""
        <RangeInput form="volume" field="percent" min="0" max="100" step="50" />
        """
      end

    assert html =~ """
           <input id="volume_percent" max="100" min="0" name="volume[percent]" step="50" type="range">
           """
  end

  test "setting the value" do
    html =
      render_surface do
        ~F"""
        <RangeInput form="volume" field="percent" min="0" max="100" value="25" />
        """
      end

    assert html =~ """
           <input id="volume_percent" max="100" min="0" name="volume[percent]" type="range" value="25">
           """
  end

  test "setting the class" do
    html =
      render_surface do
        ~F"""
        <RangeInput form="volume" field="percent" min="0" max="100" class="input" />
        """
      end

    assert html =~ ~r/class="input"/
  end

  test "setting multiple classes" do
    html =
      render_surface do
        ~F"""
        <RangeInput form="volume" field="percent" min="0" max="100" class="input primary" />
        """
      end

    assert html =~ ~r/class="input primary"/
  end

  test "passing other options" do
    html =
      render_surface do
        ~F"""
        <RangeInput form="volume" field="percent" min="0" max="100" opts={disabled: "disabled"} />
        """
      end

    assert html =~ """
           <input disabled="disabled" id="volume_percent" max="100" min="0" name="volume[percent]" type="range">
           """
  end

  test "events with parent live view as target" do
    html =
      render_surface do
        ~F"""
        <RangeInput form="user" field="color" value="25" click="my_click" />
        """
      end

    assert html =~ ~s(phx-click="my_click")
  end

  test "setting id and name through props" do
    html =
      render_surface do
        ~F"""
        <RangeInput form="user" field="percent" id="rate" name="rate" />
        """
      end

    assert html =~ """
           <input id="rate" name="rate" type="range">
           """
  end

  test "setting the phx-value-* values" do
    html =
      render_surface do
        ~F"""
        <RangeInput form="volume" field="percent" values={a: "one", b: :two, c: 3} />
        """
      end

    assert html =~ """
           <input id="volume_percent" name="volume[percent]" phx-value-a="one" phx-value-b="two" phx-value-c="3" type="range">
           """
  end
end

defmodule Surface.Components.Form.RangeInputConfigTest do
  use Surface.ConnCase

  alias Surface.Components.Form.Input
  alias Surface.Components.Form.RangeInput

  test ":default_class config" do
    using_config RangeInput, default_class: "default_class" do
      html =
        render_surface do
          ~F"""
          <RangeInput/>
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
          <RangeInput/>
          """
        end

      assert html =~ ~r/class="inherited_default_class"/
    end
  end

  test ":default_class config overrides inherited :default_class from Form.Input" do
    using_config Input, default_class: "inherited_default_class" do
      using_config RangeInput, default_class: "default_class" do
        html =
          render_surface do
            ~F"""
            <RangeInput/>
            """
          end

        assert html =~ ~r/class="default_class"/
      end
    end
  end
end
