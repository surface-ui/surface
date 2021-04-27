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

  test "convert <If> into <#if>" do
    expected =
      convert("""
      <div>
        <If condition={{ @var }}>
          1
          </If>
        <If   condition={{ @var }}>2</If>
      </div>
      """)

    assert expected == """
    <div>
      <#if condition={ @var }>
        1
        </#if>
      <#if   condition={ @var }>2</#if>
    </div>
    """
  end

  test "convert :if into #if" do
    expected =
      convert("""
      <div :if={{ true }}>
        1
      </div>
      <div
        :if = {{ true }}>1</div>
      """)

    assert expected == """
    <div #if={ true }>
      1
    </div>
    <div
      #if = { true }>1</div>
    """
  end
end
