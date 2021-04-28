defmodule Surface.Compiler.Converter_0_4Test do
  use ExUnit.Case, async: true

  alias Surface.Compiler.Converter
  alias Surface.Compiler.Converter_0_4

  defp convert(text) do
    Converter.convert(text, converter: Converter_0_4)
  end

  test "don't convert code inside macros" do
    expected =
      convert("""
      <template slot="footer">Footer</template>
      <#Raw>
        <template slot="footer">Footer</template>
      </#Raw>
      """)

    assert expected == """
    <#template slot="footer">Footer</#template>
    <#Raw>
      <template slot="footer">Footer</template>
    </#Raw>
    """
  end

  test "convert <template> into <#template>" do
    expected =
      convert("""
      <div>
        <template slot="footer">
          Footer
        </template>
      </div>
      """)

    assert expected == """
    <div>
      <#template slot="footer">
        Footer
      </#template>
    </div>
    """
  end

  test "convert <slot> into <#slot>" do
    expected =
      convert("""
      <div>
        <slot name="footer">
          Footer
        </slot>
      </div>
      """)

    assert expected == """
    <div>
      <#slot name="footer">
        Footer
      </#slot>
    </div>
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
      <#if condition={{ @var }}>
        1
        </#if>
      <#if   condition={{ @var }}>2</#if>
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
    <div #if={{ true }}>
      1
    </div>
    <div
      #if = {{ true }}>1</div>
    """
  end

  test "convert unquoted string" do
    expected =
      convert("""
      <div disabled=true>
        1
      </div>
      <div
        tabindex=2>2</div>
      """)

    assert expected == """
    <div disabled={{true}}>
      1
    </div>
    <div
      tabindex={{2}}>2</div>
    """
  end
end
