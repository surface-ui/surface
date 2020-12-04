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
        <TimeSelect form="alarm" field="time" value={{ %{hour: 2, minute: 11, second: 13} }} second={{ [] }} />
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
        <TimeSelect form="alarm" field="time" value={{ {2, 11, 13} }} second={{ [] }} />
        """
      end

    content = render_live(code)

    assert content =~ ~s(<option value="2" selected="selected">02</option>)
    assert content =~ ~s(<option value="11" selected="selected">11</option>)
    assert content =~ ~s(<option value="13" selected="selected">13</option>)
  end

  test "setting the default value as map" do
    code =
      quote do
        ~H"""
        <TimeSelect form="alarm" field="time" default={{ %{hour: 2, minute: 11, second: 13} }} second={{ [] }} />
        """
      end

    content = render_live(code)

    assert content =~ ~s(<option value="2" selected="selected">02</option>)
    assert content =~ ~s(<option value="11" selected="selected">11</option>)
    assert content =~ ~s(<option value="13" selected="selected">13</option>)
  end

  test "setting the default value as tuple" do
    code =
      quote do
        ~H"""
        <TimeSelect form="alarm" field="time" default={{ {2, 11, 13} }} second={{ [] }} />
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
        <TimeSelect form="alarm" field="time" second={{ [] }} />
        """
      end

    content = render_live(code)

    assert content =~ ~s(<select id="alarm_time_hour" name="alarm[time][hour]">)
    assert content =~ ~s(<select id="alarm_time_minute" name="alarm[time][minute]">)
    assert content =~ ~s(<select id="alarm_time_second" name="alarm[time][second]">)
  end

  test "passing builder to select" do
    code =
      quote do
        ~H"""
        <TimeSelect
          form="user"
          field="born_at"
          builder={{ fn b ->
            html_escape([
              "Hour: ",
              b.(:hour, class: "hour"),
              "Minute: ",
              b.(:minute, class: "minute"),
              "Second: ",
              b.(:second, class: "second"),
            ])
          end }}
        />
        """
      end

    content = render_live(code)

    assert content =~ ~s(Hour: <select class="hour" id="user_born_at_hour")
    assert content =~ ~s(Minute: <select class="minute" id="user_born_at_minute")
    assert content =~ ~s(Second: <select class="second" id="user_born_at_second")
  end

  test "passing options to hour, minute and second" do
    code =
      quote do
        ~H"""
        <TimeSelect
          form="user"
          field="born_at"
          hour={{ prompt: "Hour" }}
          minute={{ prompt: "Minute" }}
          second={{ prompt: "Second" }}
        />
        """
      end

    content = render_live(code)

    assert content =~ ~s(<option value="">Hour</option>)
    assert content =~ ~s(<option value="">Minute</option>)
    assert content =~ ~s(<option value="">Second</option>)
  end

  test "parsing class option in hour, minute and second" do
    code =
      quote do
        ~H"""
        <TimeSelect
          form="user"
          field="born_at"
          hour={{ class: ["true-class": true, "false-class": false] }}
          minute={{ class: ["true-class": true, "false-class": false] }}
          second={{ class: "second-class" }}
        />
        """
      end

    content = render_live(code)

    assert content =~
             ~s(<select class="true-class" id="user_born_at_hour" name="user[born_at][hour]">)

    assert content =~
             ~s(<select class="true-class" id="user_born_at_minute" name="user[born_at][minute]">)

    assert content =~
             ~s(<select class="second-class" id="user_born_at_second" name="user[born_at][second]">)
  end

  test "passing extra options" do
    code =
      quote do
        ~H"""
        <TimeSelect
          form="user"
          field="born_at"
          second={{ [] }}
          id="born_at"
          name="born_at"
        />
        """
      end

    content = render_live(code)

    assert content =~
             ~s(<select id="born_at_hour" name="born_at[hour]">)

    assert content =~
             ~s(<select id="born_at_minute" name="born_at[minute]">)

    assert content =~
             ~s(<select id="born_at_second" name="born_at[second]">)
  end
end
