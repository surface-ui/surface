defmodule Surface.Compiler.Converter_0_5Test do
  use ExUnit.Case, async: true

  alias Surface.Compiler.Converter
  alias Surface.Compiler.Converter_0_5

  defp convert(text) do
    Converter.convert(text, converter: Converter_0_5)
  end

  test "convert {{ }} into { }" do
    expected =
      convert("""
      <div
        id={{ @id }}   class={{@class}}
        phone = {{ @phone }}
      >
        <span title={{123}} />
        1{{ @name }}2 3{{ @name }}4
            5 {{ @value }} 6
      7 </div>
      """)

    assert expected == """
    <div
      id={ @id }   class={@class}
      phone = { @phone }
    >
      <span title={123} />
      1{ @name }2 3{ @name }4
          5 { @value } 6
    7 </div>
    """
  end

  test "convert slot's :props into :args" do
    expected =
      convert("""
      <div :props=""/>
      <#slot :props=""/>
      <div :props=""/>
      """)

    assert expected == """
    <div :props=""/>
    <#slot :args=""/>
    <div :props=""/>
    """
  end
end
