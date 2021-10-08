defmodule Surface.Components.Form.DateSelectTest do
  use Surface.ConnCase, async: true

  alias Surface.Components.Form
  alias Surface.Components.Form.DateSelect

  test "datetime select" do
    html =
      render_surface do
        ~F"""
        <DateSelect form="user" field="born_at" />
        """
      end

    assert html =~ ~s(<select id="user_born_at_year" name="user[born_at][year]">)
    assert html =~ ~s(<select id="user_born_at_month" name="user[born_at][month]">)
    assert html =~ ~s(<select id="user_born_at_day" name="user[born_at][day]">)
  end

  test "with form context" do
    html =
      render_surface do
        ~F"""
        <Form for={:user}>
          <DateSelect field={:born_at} />
        </Form>
        """
      end

    assert html =~ ~s(<form action="#" method="post">)
    assert html =~ ~s(<select id="user_born_at_year" name="user[born_at][year]">)
    assert html =~ ~s(<select id="user_born_at_month" name="user[born_at][month]">)
    assert html =~ ~s(<select id="user_born_at_day" name="user[born_at][day]">)
  end

  test "setting the value as map" do
    html =
      render_surface do
        ~F"""
        <DateSelect form="user" field="born_at" value={%{year: 2020, month: 10, day: 9}} />
        """
      end

    assert html =~ ~s(<option selected value="2020">2020</option>)
    assert html =~ ~s(<option selected value="10">October</option>)
    assert html =~ ~s(<option selected value="9">09</option>)
  end

  test "setting the value as tuple" do
    html =
      render_surface do
        ~F"""
        <DateSelect form="user" field="born_at" value={{2020, 10, 9}} />
        """
      end

    assert html =~ ~s(<option selected value="2020">2020</option>)
    assert html =~ ~s(<option selected value="10">October</option>)
    assert html =~ ~s(<option selected value="9">09</option>)
  end

  test "setting the default value as map" do
    html =
      render_surface do
        ~F"""
        <DateSelect form="user" field="born_at" default={%{year: 2020, month: 10, day: 9}} />
        """
      end

    assert html =~ ~s(<option selected value="2020">2020</option>)
    assert html =~ ~s(<option selected value="10">October</option>)
    assert html =~ ~s(<option selected value="9">09</option>)
  end

  test "setting the default value as tuple" do
    html =
      render_surface do
        ~F"""
        <DateSelect form="user" field="born_at" default={{2020, 10, 9}} />
        """
      end

    assert html =~ ~s(<option selected value="2020">2020</option>)
    assert html =~ ~s(<option selected value="10">October</option>)
    assert html =~ ~s(<option selected value="9">09</option>)
  end

  test "passing options to year, month and day" do
    html =
      render_surface do
        ~F"""
        <DateSelect
          form="user"
          field="born_at"
          year={prompt: "Year"}
          month={prompt: "Month"}
          day={prompt: "Day"}
        />
        """
      end

    assert html =~ ~s(<option value="">Year</option>)
    assert html =~ ~s(<option value="">Month</option>)
    assert html =~ ~s(<option value="">Day</option>)
  end

  test "passing builder to select" do
    html =
      render_surface do
        ~F"""
        <DateSelect
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
            ]
          end}
        />
        """
      end

    assert html =~ ~s(Year: <select class="year" id="user_born_at_year")
    assert html =~ ~s(Month: <select class="month" id="user_born_at_month")
    assert html =~ ~s(Day: <select class="day" id="user_born_at_day")
  end

  test "parsing class option in year, month and day" do
    html =
      render_surface do
        ~F"""
        <DateSelect
          form="user"
          field="born_at"
          year={class: ["true-class": true, "false-class": false]}
          month={class: ["true-class": true, "false-class": false]}
          day={class: "day-class"}
        />
        """
      end

    assert html =~
             ~s(<select class="true-class" id="user_born_at_year" name="user[born_at][year]">)

    assert html =~
             ~s(<select class="true-class" id="user_born_at_month" name="user[born_at][month]">)

    assert html =~ ~s(<select class="day-class" id="user_born_at_day" name="user[born_at][day]">)
  end

  test "passing id and name through props" do
    html =
      render_surface do
        ~F"""
        <DateSelect
          form="user"
          field="born_at"
          id="born_at"
          name="born_at"
        />
        """
      end

    assert html =~ ~s(<select id="born_at_year" name="born_at[year]">)
    assert html =~ ~s(<select id="born_at_month" name="born_at[month]">)
    assert html =~ ~s(<select id="born_at_day" name="born_at[day]">)
  end
end
