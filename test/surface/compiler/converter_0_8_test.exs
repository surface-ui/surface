defmodule Surface.Compiler.Converter_0_8Test do
  use ExUnit.Case, async: true

  alias Mix.Tasks.Surface.Convert
  alias Surface.Compiler.Converter
  alias Surface.Compiler.Converter_0_8

  defp convert(text) do
    Converter.convert(text, converter: Converter_0_8)
  end

  defp convert_file_content(file_name \\ "nofile.ex", content) do
    Convert.convert_file_contents!(file_name, content, Converter_0_8)
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

  test "replace inside ~F sigils" do
    sigil_delimiters = [{~s("""), ~s(""")}, {~s("), ~s(")}, {"[", "]"}, {"(", ")"}, {"{", "}"}]

    for {open, close} <- sigil_delimiters do
      code = """
      ~F#{open}
      <#template>Content</#template>
      #{close}
      """

      assert convert_file_content(code) === """
             ~F#{open}
             <:default>Content</:default>
             #{close}
             """
    end
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

  test ~S'convert <#slot> with name to root prop' do
    code =
      convert("""
      <#slot name="header"/>
      """)

    assert code == """
           <#slot {@header} />
           """
  end

  test ~S'convert <#slot> with for to root prop' do
    code =
      convert("""
      <#slot for={@header}/>
      """)

    assert code == """
           <#slot {@header} />
           """
  end

  test ~S'convert <#slot> with for and fallback content to root prop' do
    code =
      convert("""
      <#slot for={@content}>
        No content defined!
      </#slot>
      """)

    assert code == """
           <#slot {@content}>
             No content defined!
           </#slot>
           """
  end

  test ~S'convert <#slot> with for and :args to root prop' do
    code =
      convert("""
      <#slot for={@header} :args={age: @age}/>
      """)

    assert code == """
           <#slot {@header, age: @age} />
           """
  end

  test ~S'convert <#slot> with for variable and :args to root prop' do
    code =
      convert("""
      <#slot for={col} :args={age: @age}/>
      """)

    assert code == """
           <#slot {col, age: @age} />
           """
  end

  test ~S'convert <#slot> with :args to root prop for default slot' do
    code =
      convert("""
      <#slot :args={name: "Joe"} />
      """)

    assert code == """
           <#slot {@default, name: "Joe"} />
           """
  end

  test ~S'convert <#slot> with name and :args to root prop' do
    code =
      convert("""
      <#slot name="footer" :args={name: "Joe"} />
      """)

    assert code == """
           <#slot {@footer, name: "Joe"} />
           """
  end

  test ~S'convert <#slot> with :if and :for directives' do
    code =
      convert("""
      <#slot :if={@condition} :for={user <- @users} name="user" :args={user: user} />
      """)

    assert code == """
           <#slot {@user, user: user} :if={@condition} :for={user <- @users} />
           """
  end

  test ~S"don't convert <#slot> with name and index" do
    code =
      convert("""
      <#slot name="col" index={index}/>
      """)

    assert code == """
           <#slot name="col" index={index}/>
           """
  end

  test ~S"don't convert <#slot/> without attributes" do
    code =
      convert("""
      <#slot/>
      """)

    assert code == """
           <#slot/>
           """
  end

  test ~S"don't convert new <#slot/> syntax" do
    code =
      convert("""
      <#slot {@map, name: "Joe", age: "32"} generator_value={label} />
      """)

    assert code == """
           <#slot {@map, name: "Joe", age: "32"} generator_value={label} />
           """
  end
end
