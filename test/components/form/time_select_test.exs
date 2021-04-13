defmodule Surface.Components.Form.TimeSelectTest do
  use Surface.ConnCase, async: true

  alias Surface.Components.Form
  alias Surface.Components.Form.TimeSelect

  test "datetime select" do
    html =
      render_surface do
        ~H"""
        <TimeSelect form="alarm" field="time" />
        """
      end

    assert html =~ ~s(<select id="alarm_time_hour" name="alarm[time][hour]">)
    assert html =~ ~s(<select id="alarm_time_minute" name="alarm[time][minute]">)
  end

  test "with form context" do
    html =
      render_surface do
        ~H"""
        <Form for={{ :alarm }}>
          <TimeSelect field={{ :time }} />
        </Form>
        """
      end

    assert html =~ ~s(<form action="#" method="post">)
    assert html =~ ~s(<select id="alarm_time_hour" name="alarm[time][hour]">)
    assert html =~ ~s(<select id="alarm_time_minute" name="alarm[time][minute]">)
  end

  test "setting the value as map" do
    html =
      render_surface do
        ~H"""
        <TimeSelect form="alarm" field="time" value={{ %{hour: 2, minute: 11, second: 13} }} second={{ [] }} />
        """
      end

    assert html =~ ~s(<option value="2" selected>02</option>)
    assert html =~ ~s(<option value="11" selected>11</option>)
    assert html =~ ~s(<option value="13" selected>13</option>)
  end

  test "setting the value as tuple" do
    html =
      render_surface do
        ~H"""
        <TimeSelect form="alarm" field="time" value={{ {2, 11, 13} }} second={{ [] }} />
        """
      end

    assert html =~ ~s(<option value="2" selected>02</option>)
    assert html =~ ~s(<option value="11" selected>11</option>)
    assert html =~ ~s(<option value="13" selected>13</option>)
  end

  test "setting the default value as map" do
    html =
      render_surface do
        ~H"""
        <TimeSelect form="alarm" field="time" default={{ %{hour: 2, minute: 11, second: 13} }} second={{ [] }} />
        """
      end

    assert html =~ ~s(<option value="2" selected>02</option>)
    assert html =~ ~s(<option value="11" selected>11</option>)
    assert html =~ ~s(<option value="13" selected>13</option>)
  end

  test "setting the default value as tuple" do
    html =
      render_surface do
        ~H"""
        <TimeSelect form="alarm" field="time" default={{ {2, 11, 13} }} second={{ [] }} />
        """
      end

    assert html =~ ~s(<option value="2" selected>02</option>)
    assert html =~ ~s(<option value="11" selected>11</option>)
    assert html =~ ~s(<option value="13" selected>13</option>)
  end

  test "passing other options" do
    html =
      render_surface do
        ~H"""
        <TimeSelect form="alarm" field="time" second={{ [] }} />
        """
      end

    assert html =~ ~s(<select id="alarm_time_hour" name="alarm[time][hour]">)
    assert html =~ ~s(<select id="alarm_time_minute" name="alarm[time][minute]">)
    assert html =~ ~s(<select id="alarm_time_second" name="alarm[time][second]">)
  end

  test "passing builder to select" do
    html =
      render_surface do
        ~H"""
        <TimeSelect
          form="user"
          field="born_at"
          builder={{ fn b ->
            [
              "Hour: ",
              b.(:hour, class: "hour"),
              "Minute: ",
              b.(:minute, class: "minute"),
              "Second: ",
              b.(:second, class: "second"),
            ]
          end }}
        />
        """
      end

    assert html =~ ~s(Hour: <select class="hour" id="user_born_at_hour")
    assert html =~ ~s(Minute: <select class="minute" id="user_born_at_minute")
    assert html =~ ~s(Second: <select class="second" id="user_born_at_second")
  end

  test "passing options to hour, minute and second" do
    html =
      render_surface do
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

    assert html =~ ~s(<option value="">Hour</option>)
    assert html =~ ~s(<option value="">Minute</option>)
    assert html =~ ~s(<option value="">Second</option>)
  end

  test "parsing class option in hour, minute and second" do
    html =
      render_surface do
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

    assert html =~
             ~s(<select class="true-class" id="user_born_at_hour" name="user[born_at][hour]">)

    assert html =~
             ~s(<select class="true-class" id="user_born_at_minute" name="user[born_at][minute]">)

    assert html =~
             ~s(<select class="second-class" id="user_born_at_second" name="user[born_at][second]">)
  end

  test "passing extra options" do
    html =
      render_surface do
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

    assert html =~ ~s(<select id="born_at_hour" name="born_at[hour]">)
    assert html =~ ~s(<select id="born_at_minute" name="born_at[minute]">)
    assert html =~ ~s(<select id="born_at_second" name="born_at[second]">)
  end
end
