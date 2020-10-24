defmodule Surface.Components.Form.TimeSelectTest do
  use ExUnit.Case, async: true

  import ComponentTestHelper
  alias Surface.Components.Form, warn: false
  alias Surface.Components.Form.TimeSelect, warn: false

  test "datetime select" do
    code =
      quote do
        ~H"""
        <TimeSelect form="alarm" field="time" />
        """
      end

    content = render_live(code)

    assert content =~ ~s(<select id="alarm_time_hour" name="alarm[time][hour]">)
    assert content =~ ~s(<select id="alarm_time_minute" name="alarm[time][minute]">)
  end

  test "with form context" do
    code =
      quote do
        ~H"""
        <Form for={{ :alarm }}>
          <TimeSelect field={{ :time }} />
        </Form>
        """
      end

    content = render_live(code)

    assert content =~ ~s(<form action="#" method="post">)
    assert content =~ ~s(<select id="alarm_time_hour" name="alarm[time][hour]">)
    assert content =~ ~s(<select id="alarm_time_minute" name="alarm[time][minute]">)
  end

  test "setting the value as map" do
    code =
      quote do
        ~H"""
        <TimeSelect form="alarm" field="time" value={{ %{hour: 2, minute: 11, second: 13} }} opts={{ second: [] }} />
        """
      end

    content = render_live(code)

    assert content =~ ~s(<option value="2" selected="selected">02</option>)
    assert content =~ ~s(<option value="11" selected="selected">11</option>)
    assert content =~ ~s(<option value="13" selected="selected">13</option>)
  end

  test "setting the value as tuple" do
    code =
      quote do
        ~H"""
        <TimeSelect form="alarm" field="time" value={{ {2, 11, 13} }} opts={{ second: [] }} />
        """
      end

    content = render_live(code)

    assert content =~ ~s(<option value="2" selected="selected">02</option>)
    assert content =~ ~s(<option value="11" selected="selected">11</option>)
    assert content =~ ~s(<option value="13" selected="selected">13</option>)
  end

  test "passing other options" do
    code =
      quote do
        ~H"""
        <TimeSelect form="alarm" field="time" opts={{ second: [] }} />
        """
      end

    content = render_live(code)

    assert content =~ ~s(<select id="alarm_time_hour" name="alarm[time][hour]">)
    assert content =~ ~s(<select id="alarm_time_minute" name="alarm[time][minute]">)
    assert content =~ ~s(<select id="alarm_time_second" name="alarm[time][second]">)
  end
end
