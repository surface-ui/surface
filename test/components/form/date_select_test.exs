defmodule Surface.Components.Form.DateSelectTest do
  use ExUnit.Case, async: true

  import ComponentTestHelper
  alias Surface.Components.Form, warn: false
  alias Surface.Components.Form.DateSelect, warn: false

  test "datetime select" do
    code =
      quote do
        ~H"""
        <DateSelect form="user" field="born_at" />
        """
      end

    content = render_live(code)

    assert content =~ ~s(<select id="user_born_at_year" name="user[born_at][year]">)
    assert content =~ ~s(<select id="user_born_at_month" name="user[born_at][month]">)
    assert content =~ ~s(<select id="user_born_at_day" name="user[born_at][day]">)
  end

  test "with form context" do
    code =
      quote do
        ~H"""
        <Form for={{ :user }}>
          <DateSelect field={{ :born_at }} />
        </Form>
        """
      end

    content = render_live(code)

    assert content =~ ~s(<form action="#" method="post">)
    assert content =~ ~s(<select id="user_born_at_year" name="user[born_at][year]">)
    assert content =~ ~s(<select id="user_born_at_month" name="user[born_at][month]">)
    assert content =~ ~s(<select id="user_born_at_day" name="user[born_at][day]">)
  end

  test "setting the value as map" do
    code =
      quote do
        ~H"""
        <DateSelect form="user" field="born_at" value={{ %{year: 2020, month: 10, day: 9} }} />
        """
      end

    content = render_live(code)

    assert content =~ ~s(<option value="2020" selected="selected">2020</option>)
    assert content =~ ~s(<option value="10" selected="selected">October</option>)
    assert content =~ ~s(<option value="9" selected="selected">09</option>)
  end

  test "setting the value as tuple" do
    code =
      quote do
        ~H"""
        <DateSelect form="user" field="born_at" value={{ {2020, 10, 9} }} />
        """
      end

    content = render_live(code)

    assert content =~ ~s(<option value="2020" selected="selected">2020</option>)
    assert content =~ ~s(<option value="10" selected="selected">October</option>)
    assert content =~ ~s(<option value="9" selected="selected">09</option>)
  end

  test "setting the default value as map" do
    code =
      quote do
        ~H"""
        <DateSelect form="user" field="born_at" default={{ %{year: 2020, month: 10, day: 9} }} />
        """
      end

    content = render_live(code)

    assert content =~ ~s(<option value="2020" selected="selected">2020</option>)
    assert content =~ ~s(<option value="10" selected="selected">October</option>)
    assert content =~ ~s(<option value="9" selected="selected">09</option>)
  end

  test "setting the default value as tuple" do
    code =
      quote do
        ~H"""
        <DateSelect form="user" field="born_at" default={{ {2020, 10, 9} }} />
        """
      end

    content = render_live(code)

    assert content =~ ~s(<option value="2020" selected="selected">2020</option>)
    assert content =~ ~s(<option value="10" selected="selected">October</option>)
    assert content =~ ~s(<option value="9" selected="selected">09</option>)
  end

  test "passing options to year, month and day" do
    code =
      quote do
        ~H"""
        <DateSelect
          form="user"
          field="born_at"
          year={{ prompt: "Year" }}
          month={{ prompt: "Month" }}
          day={{ prompt: "Day" }}
        />
        """
      end

    content = render_live(code)

    assert content =~ ~s(<option value="">Year</option>)
    assert content =~ ~s(<option value="">Month</option>)
    assert content =~ ~s(<option value="">Day</option>)
  end

  test "passing builder to select" do
    code =
      quote do
        ~H"""
        <DateSelect
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
            ])
          end }}
        />
        """
      end

    content = render_live(code)

    assert content =~ ~s(Year: <select class="year" id="user_born_at_year")
    assert content =~ ~s(Month: <select class="month" id="user_born_at_month")
    assert content =~ ~s(Day: <select class="day" id="user_born_at_day")
  end

  test "parsing class option in year, month and day" do
    code =
      quote do
        ~H"""
        <DateSelect
          form="user"
          field="born_at"
          year={{ class: ["true-class": true, "false-class": false] }}
          month={{ class: ["true-class": true, "false-class": false] }}
          day={{ class: "day-class" }}
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
  end

  test "passing id and name through props" do
    code =
      quote do
        ~H"""
        <DateSelect
          form="user"
          field="born_at"
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
  end
end
