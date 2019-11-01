defmodule TranslatorTest do
  use ExUnit.Case

  defmodule Button do
    use Surface.Component

    property label, :string, default: ""
    property click, :event
    property class, :css_class

    def render(assigns) do
      ~H"""
      <button />
      """
    end
  end

  test "tag with expression" do
    code = """
    <div label={{ @label }}/>
    """

    translated = Surface.Translator.run(code, 0, __ENV__)
    assert translated =~ """
    <div label="<%= @label %>"/>
    """
  end

  test "tag with expressions inside a string" do
    code = """
    <div label="str_1 {{@str_2}} str_3 {{@str_4 <> @str_5}}"/>
    """

    translated = Surface.Translator.run(code, 0, __ENV__)
    assert translated =~ """
    <div label="str_1 <%= @str_2 %> str_3 <%= @str_4 <> @str_5 %>"/>
    """
  end

  test "tag with css_class property as string" do
    code = """
    <div class="firstClass"/>
    """

    translated = Surface.Translator.run(code, 0, __ENV__)
    assert translated =~ """
    <div class="firstClass"/>
    """
  end

  test "tag with css_class property as keyword list" do
    code = """
    <div class={{ "firstClass", secondClass: var }}/>
    """

    translated = Surface.Translator.run(code, 0, __ENV__)
    assert translated =~ """
    <div class="<%= css_class([ "firstClass", secondClass: var ]) %>"/>
    """
  end

  test "component with expression" do
    code = """
    <Button label={{ @label }}/>
    """
    translated = Surface.Translator.run(code, 0, __ENV__)

    assert translated =~ """
    %{label: (@label),\
    """
  end

  test "component with expressions inside a string" do
    code = """
    <Button label="str_1 {{@str_2}} str_3 {{@str_4 <> @str_5}}" />
    """
    translated = Surface.Translator.run(code, 0, __ENV__)

    assert translated =~ """
    %{label: "str_1 \#{@str_2} str_3 \#{@str_4 <> @str_5}",\
    """
  end

  test "component with events" do
    code = """
    <Button click="click_event" />
    """
    translated = Surface.Translator.run(code, 0, __ENV__)

    assert translated =~ """
    %{click: "click_event",\
    """
  end
end

