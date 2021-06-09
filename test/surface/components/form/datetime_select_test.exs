defmodule Surface.Components.Form.DateTimeSelectTest do
  use Surface.ConnCase, async: true

  alias Surface.Components.Form
  alias Surface.Components.Form.DateTimeSelect

  test "datetime select" do
    html =
      render_surface do
        ~F"""
        <DateTimeSelect form="user" field="born_at" />
        """
      end

    assert html =~ ~s(<select id="user_born_at_year" name="user[born_at][year]">)
    assert html =~ ~s(<select id="user_born_at_month" name="user[born_at][month]">)
    assert html =~ ~s(<select id="user_born_at_day" name="user[born_at][day]">)
    assert html =~ ~s(<select id="user_born_at_hour" name="user[born_at][hour]">)
    assert html =~ ~s(<select id="user_born_at_minute" name="user[born_at][minute]">)
  end

  test "with form context" do
    html =
      render_surface do
        ~F"""
        <Form for={:user}>
          <DateTimeSelect field={:born_at} />
        </Form>
        """
      end

    assert html =~ ~s(<form action="#" method="post">)
    assert html =~ ~s(<select id="user_born_at_year" name="user[born_at][year]">)
    assert html =~ ~s(<select id="user_born_at_month" name="user[born_at][month]">)
    assert html =~ ~s(<select id="user_born_at_day" name="user[born_at][day]">)
    assert html =~ ~s(<select id="user_born_at_hour" name="user[born_at][hour]">)
    assert html =~ ~s(<select id="user_born_at_minute" name="user[born_at][minute]">)
  end

  test "setting the value as map" do
    html =
      render_surface do
        ~F"""
        <DateTimeSelect form="user" field="born_at" value={%{year: 2020, month: 10, day: 9, hour: 2, minute: 11, second: 13}} second={[]} />
        """
      end

    assert html =~ ~s(<option value="2020" selected>2020</option>)
    assert html =~ ~s(<option value="10" selected>October</option>)
    assert html =~ ~s(<option value="9" selected>09</option>)
    assert html =~ ~s(<option value="2" selected>02</option>)
    assert html =~ ~s(<option value="11" selected>11</option>)
    assert html =~ ~s(<option value="13" selected>13</option>)
  end

  test "setting the value as tuple" do
    html =
      render_surface do
        ~F"""
        <DateTimeSelect form="user" field="born_at" value={{ {2020, 10, 9}, {2, 11, 13} }} second={[]} />
        """
      end

    assert html =~ ~s(<option value="2020" selected>2020</option>)
    assert html =~ ~s(<option value="10" selected>October</option>)
    assert html =~ ~s(<option value="9" selected>09</option>)
    assert html =~ ~s(<option value="2" selected>02</option>)
    assert html =~ ~s(<option value="11" selected>11</option>)
    assert html =~ ~s(<option value="13" selected>13</option>)
  end

  test "setting the default value as map" do
    html =
      render_surface do
        ~F"""
        <DateTimeSelect form="user" field="born_at" default={%{year: 2020, month: 10, day: 9, hour: 2, minute: 11, second: 13}} second={[]} />
        """
      end

    assert html =~ ~s(<option value="2020" selected>2020</option>)
    assert html =~ ~s(<option value="10" selected>October</option>)
    assert html =~ ~s(<option value="9" selected>09</option>)
    assert html =~ ~s(<option value="2" selected>02</option>)
    assert html =~ ~s(<option value="11" selected>11</option>)
    assert html =~ ~s(<option value="13" selected>13</option>)
  end

  test "setting the default value as tuple" do
    html =
      render_surface do
        ~F"""
        <DateTimeSelect form="user" field="born_at" default={{ {2020, 10, 9}, {2, 11, 13} }} second={[]} />
        """
      end

    assert html =~ ~s(<option value="2020" selected>2020</option>)
    assert html =~ ~s(<option value="10" selected>October</option>)
    assert html =~ ~s(<option value="9" selected>09</option>)
    assert html =~ ~s(<option value="2" selected>02</option>)
    assert html =~ ~s(<option value="11" selected>11</option>)
    assert html =~ ~s(<option value="13" selected>13</option>)
  end

  test "passing builder to select" do
    html =
      render_surface do
        ~F"""
        <DateTimeSelect
          form="user"
          field="born_at"
          builder={fn b ->
            [
              "Year: ",
              b.(:year, class: "year"),
              "Month: ",
              b.(:month, class: "month"),
              "Day: ",
              b.(:day, class: "day"),
              "Hour: ",
              b.(:hour, class: "hour"),
              "Minute: ",
              b.(:minute, class: "minute"),
              "Second: ",
              b.(:second, class: "second"),
            ]
          end}
        />
        """
      end

    assert html =~ ~s(Year: <select class="year" id="user_born_at_year")
    assert html =~ ~s(Month: <select class="month" id="user_born_at_month")
    assert html =~ ~s(Day: <select class="day" id="user_born_at_day")
    assert html =~ ~s(Hour: <select class="hour" id="user_born_at_hour")
    assert html =~ ~s(Minute: <select class="minute" id="user_born_at_minute")
    assert html =~ ~s(Second: <select class="second" id="user_born_at_second")
  end

  test "passing options to year, month, day, hour, minute and second" do
    html =
      render_surface do
        ~F"""
        <DateTimeSelect
          form="user"
          field="born_at"
          year={prompt: "Year"}
          month={prompt: "Month"}
          day={prompt: "Day"}
          hour={prompt: "Hour"}
          minute={prompt: "Minute"}
          second={prompt: "Second"}
        />
        """
      end

    assert html =~ ~s(<option value="">Year</option>)
    assert html =~ ~s(<option value="">Month</option>)
    assert html =~ ~s(<option value="">Day</option>)
    assert html =~ ~s(<option value="">Hour</option>)
    assert html =~ ~s(<option value="">Minute</option>)
    assert html =~ ~s(<option value="">Second</option>)
  end

  test "parsing class option in year, month, day, hour, minute and second" do
    html =
      render_surface do
        ~F"""
        <DateTimeSelect
          form="user"
          field="born_at"
          year={class: ["true-class": true, "false-class": false]}
          month={class: ["true-class": true, "false-class": false]}
          day={class: "day-class"}
          hour={class: ["true-class": true, "false-class": false]}
          minute={class: ["true-class": true, "false-class": false]}
          second={class: "second-class"}
        />
        """
      end

    assert html =~
             ~s(<select class="true-class" id="user_born_at_year" name="user[born_at][year]">)

    assert html =~
             ~s(<select class="true-class" id="user_born_at_month" name="user[born_at][month]">)

    assert html =~
             ~s(<select class="day-class" id="user_born_at_day" name="user[born_at][day]">)

    assert html =~
             ~s(<select class="true-class" id="user_born_at_hour" name="user[born_at][hour]">)

    assert html =~
             ~s(<select class="true-class" id="user_born_at_minute" name="user[born_at][minute]">)

    assert html =~
             ~s(<select class="second-class" id="user_born_at_second" name="user[born_at][second]">)
  end

  test "passing id and name through props" do
    html =
      render_surface do
        ~F"""
        <DateTimeSelect
          form="user"
          field="born_at"
          second={[]}
          id="born_at"
          name="born_at"
        />
        """
      end

    assert html =~ ~s(<select id="born_at_year" name="born_at[year]">)
    assert html =~ ~s(<select id="born_at_month" name="born_at[month]">)
    assert html =~ ~s(<select id="born_at_day" name="born_at[day]">)
    assert html =~ ~s(<select id="born_at_hour" name="born_at[hour]">)
    assert html =~ ~s(<select id="born_at_minute" name="born_at[minute]">)
    assert html =~ ~s(<select id="born_at_second" name="born_at[second]">)
  end
end
