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
        <DateTimeSelect form="user" field="born_at" value={{ %{year: 2020, month: 10, day: 9, hour: 2, minute: 11, second: 13} }} opts={{ second: [] }} />
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
        <DateTimeSelect form="user" field="born_at" value={{ { {2020, 10, 9}, {2, 11, 13} } }} opts={{ second: [] }} />
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

  test "passing other options" do
    code =
      quote do
        ~H"""
        <DateTimeSelect form="user" field="born_at" opts={{ second: [] }} />
        """
      end

    content = render_live(code)

    assert content =~ ~s(<select id="user_born_at_year" name="user[born_at][year]">)
    assert content =~ ~s(<select id="user_born_at_month" name="user[born_at][month]">)
    assert content =~ ~s(<select id="user_born_at_day" name="user[born_at][day]">)
    assert content =~ ~s(<select id="user_born_at_hour" name="user[born_at][hour]">)
    assert content =~ ~s(<select id="user_born_at_minute" name="user[born_at][minute]">)
    assert content =~ ~s(<select id="user_born_at_second" name="user[born_at][second]">)
  end
end
