defmodule Surface.Compiler.Converter_0_8Test do
  use ExUnit.Case, async: true

  alias Surface.Compiler.Converter
  alias Surface.Compiler.Converter_0_8

  defp convert(text) do
    Converter.convert(text, converter: Converter_0_8)
  end

  test "don't convert code inside macros" do
    code =
      convert("""
      <#Raw>
        <div>
          <#template slot="footer">
            Footer
          </#template>
        </div>
      </#Raw>
      """)

    assert code == """
           <#Raw>
             <div>
               <#template slot="footer">
                 Footer
               </#template>
             </div>
           </#Raw>
           """
  end

  test ~S'convert <#template slot="footer"> into <:footer>' do
    code =
      convert("""
      <div>
        <#template slot="footer">
          Footer
        </#template>
      </div>
      """)

    assert code == """
           <div>
             <:footer>
               Footer
             </:footer>
           </div>
           """
  end

  test ~S'convert <#template slot="footer"> into <:footer> on same line' do
    code =
      convert("""
      <div>
        <#template slot="footer" name="123">Footer</#template>
      </div>
      """)

    assert code == """
           <div>
             <:footer>Footer</:footer>
           </div>
           """
  end

  test ~S'convert <#template> into <:default> on same line' do
    code =
      convert("""
      <div>
        <#template>Footer</#template>
      </div>
      """)

    assert code == """
           <div>
             <:default>Footer</:default>
           </div>
           """
  end
end
