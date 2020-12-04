defmodule Surface.Components.Form.DateTimeSelectTest do
  use ExUnit.Case, async: true

  import ComponentTestHelper
  alias Surface.Components.Form, warn: false
  alias Surface.Components.Form.DateTimeSelect, warn: false

  test "datetime select" do
    code =
      quote do
        ~H"""
        <DateTimeSelect form="user" field="born_at" />
        """
      end

    content = render_live(code)

    assert content =~ ~s(<select id="user_born_at_year" name="user[born_at][year]">)
    assert content =~ ~s(<select id="user_born_at_month" name="user[born_at][month]">)
    assert content =~ ~s(<select id="user_born_at_day" name="user[born_at][day]">)
    assert content =~ ~s(<select id="user_born_at_hour" name="user[born_at][hour]">)
    assert content =~ ~s(<select id="user_born_at_minute" name="user[born_at][minute]">)
  end

  test "with form context" do
    code =
      quote do
        ~H"""
        <Form for={{ :user }}>
          <DateTimeSelect field={{ :born_at }} />
        </Form>
        """
      end

    content = render_live(code)

    assert content =~ ~s(<form action="#" method="post">)
    assert content =~ ~s(<select id="user_born_at_year" name="user[born_at][year]">)
    assert content =~ ~s(<select id="user_born_at_month" name="user[born_at][month]">)
    assert content =~ ~s(<select id="user_born_at_day" name="user[born_at][day]">)
    assert content =~ ~s(<select id="user_born_at_hour" name="user[born_at][hour]">)
    assert content =~ ~s(<select id="user_born_at_minute" name="user[born_at][minute]">)
  end

  test "setting the value as map" do
    code =
      quote do
        ~H"""
        <DateTimeSelect form="user" field="born_at" value={{ %{year: 2020, month: 10, day: 9, hour: 2, minute: 11, second: 13} }} second={{ [] }} />
        """
      end

    content = render_live(code)

    assert content =~ ~s(<option value="2020" selected="selected">2020</option>)
    assert content =~ ~s(<option value="10" selected="selected">October</option>)
    assert content =~ ~s(<option value="9" selected="selected">09</option>)
    assert content =~ ~s(<option value="2" selected="selected">02</option>)
    assert content =~ ~s(<option value="11" selected="selected">11</option>)
    assert content =~ ~s(<option value="13" selected="selected">13</option>)
  end

  test "setting the value as tuple" do
    code =
      quote do
        ~H"""
        <DateTimeSelect form="user" field="born_at" value={{ { {2020, 10, 9}, {2, 11, 13} } }} second={{ [] }} />
        """
      end

    content = render_live(code)

    assert content =~ ~s(<option value="2020" selected="selected">2020</option>)
    assert content =~ ~s(<option value="10" selected="selected">October</option>)
    assert content =~ ~s(<option value="9" selected="selected">09</option>)
    assert content =~ ~s(<option value="2" selected="selected">02</option>)
    assert content =~ ~s(<option value="11" selected="selected">11</option>)
    assert content =~ ~s(<option value="13" selected="selected">13</option>)
  end

  test "setting the default value as map" do
    code =
      quote do
        ~H"""
        <DateTimeSelect form="user" field="born_at" default={{ %{year: 2020, month: 10, day: 9, hour: 2, minute: 11, second: 13} }} second={{ [] }} />
        """
      end

    content = render_live(code)

    assert content =~ ~s(<option value="2020" selected="selected">2020</option>)
    assert content =~ ~s(<option value="10" selected="selected">October</option>)
    assert content =~ ~s(<option value="9" selected="selected">09</option>)
    assert content =~ ~s(<option value="2" selected="selected">02</option>)
    assert content =~ ~s(<option value="11" selected="selected">11</option>)
    assert content =~ ~s(<option value="13" selected="selected">13</option>)
  end

  test "setting the default value as tuple" do
    code =
      quote do
        ~H"""
        <DateTimeSelect form="user" field="born_at" default={{ { {2020, 10, 9}, {2, 11, 13} } }} second={{ [] }} />
        """
      end

    content = render_live(code)

    assert content =~ ~s(<option value="2020" selected="selected">2020</option>)
    assert content =~ ~s(<option value="10" selected="selected">October</option>)
    assert content =~ ~s(<option value="9" selected="selected">09</option>)
    assert content =~ ~s(<option value="2" selected="selected">02</option>)
    assert content =~ ~s(<option value="11" selected="selected">11</option>)
    assert content =~ ~s(<option value="13" selected="selected">13</option>)
  end

  test "passing builder to select" do
    code =
      quote do
        ~H"""
        <DateTimeSelect
          form="user"
          field="born_at"
          builder={{ fn b ->
            html_escape([
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
            ])
          end }}
        />
        """
      end

    content = render_live(code)

    assert content =~ ~s(Year: <select class="year" id="user_born_at_year")
    assert content =~ ~s(Month: <select class="month" id="user_born_at_month")
    assert content =~ ~s(Day: <select class="day" id="user_born_at_day")
    assert content =~ ~s(Hour: <select class="hour" id="user_born_at_hour")
    assert content =~ ~s(Minute: <select class="minute" id="user_born_at_minute")
    assert content =~ ~s(Second: <select class="second" id="user_born_at_second")
  end

  test "passing options to year, month, day, hour, minute and second" do
    code =
      quote do
        ~H"""
        <DateTimeSelect
          form="user"
          field="born_at"
          year={{ prompt: "Year" }}
          month={{ prompt: "Month" }}
          day={{ prompt: "Day" }}
          hour={{ prompt: "Hour" }}
          minute={{ prompt: "Minute" }}
          second={{ prompt: "Second" }}
        />
        """
      end

    content = render_live(code)

    assert content =~ ~s(<option value="">Year</option>)
    assert content =~ ~s(<option value="">Month</option>)
    assert content =~ ~s(<option value="">Day</option>)
    assert content =~ ~s(<option value="">Hour</option>)
    assert content =~ ~s(<option value="">Minute</option>)
    assert content =~ ~s(<option value="">Second</option>)
  end

  test "parsing class option in year, month, day, hour, minute and second" do
    code =
      quote do
        ~H"""
        <DateTimeSelect
          form="user"
          field="born_at"
          year={{ class: ["true-class": true, "false-class": false] }}
          month={{ class: ["true-class": true, "false-class": false] }}
          day={{ class: "day-class" }}
          hour={{ class: ["true-class": true, "false-class": false] }}
          minute={{ class: ["true-class": true, "false-class": false] }}
          second={{ class: "second-class" }}
        />
        """
      end

    content = render_live(code)

    assert content =~
             ~s(<select class="true-class" id="user_born_at_year" name="user[born_at][year]">)

    assert content =~
             ~s(<select class="true-class" id="user_born_at_month" name="user[born_at][month]">)

    assert content =~
             ~s(<select class="day-class" id="user_born_at_day" name="user[born_at][day]">)

    assert content =~
             ~s(<select class="true-class" id="user_born_at_hour" name="user[born_at][hour]">)

    assert content =~
             ~s(<select class="true-class" id="user_born_at_minute" name="user[born_at][minute]">)

    assert content =~
             ~s(<select class="second-class" id="user_born_at_second" name="user[born_at][second]">)
  end

  test "passing id and name through props" do
    code =
      quote do
        ~H"""
        <DateTimeSelect
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
             ~s(<select id="born_at_year" name="born_at[year]">)

    assert content =~
             ~s(<select id="born_at_month" name="born_at[month]">)

    assert content =~
             ~s(<select id="born_at_day" name="born_at[day]">)

    assert content =~
             ~s(<select id="born_at_hour" name="born_at[hour]">)

    assert content =~
             ~s(<select id="born_at_minute" name="born_at[minute]">)

    assert content =~
             ~s(<select id="born_at_second" name="born_at[second]">)
  end
end
