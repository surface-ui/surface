defmodule Surface.Compiler.Converter_0_5Test do
  use ExUnit.Case, async: true

  alias Surface.Compiler.Converter
  alias Surface.Compiler.Converter_0_5
  alias Mix.Tasks.Surface.Convert

  defp convert(text) do
    Converter.convert(text, converter: Converter_0_5)
  end

  test "don't convert code inside macros" do
    code =
      convert("""
      <div class={{ @class }}>text</div>
      <#Raw>
        <div class={{ @class }}>text</div>
      </#Raw>
      """)

    assert code == """
           <div class={@class}>text</div>
           <#Raw>
             <div class={{ @class }}>text</div>
           </#Raw>
           """
  end

  describe "convert interpolation (expressions)" do
    test "convert {{ }} into { }" do
      code =
        convert("""
        <div
          id={{ @id }}   class={{@class}}
          phone = {{ @phone }}
        >
          <span title={{123}} />
          1{{ @name }}2 3{{@name}}4
              5 {{ @value }} 6
        7 </div>
        """)

      assert code == """
             <div
               id={@id}   class={@class}
               phone = {@phone}
             >
               <span title={123} />
               1{@name}2 3{@name}4
                   5 {@value} 6
             7 </div>
             """
    end

    test "convert {{ }} into { } even when expressions start with line breaks" do
      code =
        convert("""
        {{
          Enum.join(
            @list1,
            ","
          )
        }} text
        {
          Enum.join(
            @list2,
            ","
          )
        }
        """)

      assert code == """
             {
               Enum.join(
                 @list1,
                 ","
               )
             } text
             {
               Enum.join(
                 @list2,
                 ","
               )
             }
             """
    end

    test "keep indentation before closing `}}` " do
      code =
        convert("""
        <div>
          <div class={{
            "my_class"
          }}>
        </div>
        """)

      assert code == """
             <div>
               <div class={
                 "my_class"
               }>
             </div>
             """
    end

    test "only convert {{ }} into { } if the first and last chars are `{` and `}` respectively" do
      code =
        convert("""
        <div class={{@class}}>
          {{ @name }}
        </div>
        <div class={ {1, 2} }>
          { {3, 4} }
        </div>
        <!-- The edge case we can't distingush. This breaks the code. -->
        <Comp a_tuple={{1, 2}}>
          {{3, 4}}
        </Comp>
        """)

      assert code == """
             <div class={@class}>
               {@name}
             </div>
             <div class={ {1, 2} }>
               { {3, 4} }
             </div>
             <!-- The edge case we can't distingush. This breaks the code. -->
             <Comp a_tuple={1, 2}>
               {3, 4}
             </Comp>
             """
    end
  end

  test "convert unquoted string" do
    code =
      convert("""
      <div disabled=true>
        1
      </div>
      <div
        tabindex=2>2</div>
      """)

    assert code == """
           <div disabled={true}>
             1
           </div>
           <div
             tabindex={2}>2</div>
           """
  end

  test "convert <template> into <#template>" do
    code =
      convert("""
      <div>
        <template slot="footer">
          Footer
        </template>
      </div>
      """)

    assert code == """
           <div>
             <#template slot="footer">
               Footer
             </#template>
           </div>
           """
  end

  test "convert <slot> into <#slot>" do
    code =
      convert("""
      <div>
        <slot name="footer">
          Footer
        </slot>
      </div>
      """)

    assert code == """
           <div>
             <#slot name="footer">
               Footer
             </#slot>
           </div>
           """
  end

  test "convert <If> into {#if}" do
    code =
      convert("""
      <div>
        <If condition={{ @var }}>
          1
          </If>
        <If   condition={{@var}}>2</If>
      </div>
      """)

    assert code == """
           <div>
             {#if @var}
               1
               {/if}
             {#if @var}2{/if}
           </div>
           """
  end

  test "convert <If> multiline expression into {#if}" do
    code =
      convert("""
      <div>
        <If condition={{ @var ==
                         1 }}>
          1
          </If>
        <If   condition={{@var}}>2</If>
      </div>
      """)

    assert code == """
           <div>
             {#if @var ==
                              1}
               1
               {/if}
             {#if @var}2{/if}
           </div>
           """
  end

  test "convert <For> into <#For>" do
    code =
      convert("""
      <div>
        <For each={{ _i <- @var }}>
          1
          </For>
        <For   each={{@var}}>2</For>
      </div>
      """)

    assert code == """
           <div>
             {#for _i <- @var}
               1
               {/for}
             {#for @var}2{/for}
           </div>
           """
  end

  test "convert <For> with multiline expression into <#For>" do
    code =
      convert("""
      <div>
        <For each={{ i <- @var,
                     i > 0 }}>
          1
          </For>
        <For   each={{@var}}>2</For>
      </div>
      """)

    assert code == """
           <div>
             {#for i <- @var,
                          i > 0}
               1
               {/for}
             {#for @var}2{/for}
           </div>
           """
  end

  test "convert strings with embedded interpolation" do
    code =
      convert("""
      <img src="{{ "/" }}">
      """)

    assert code == """
           <img src={"\#{"/"}"}>
           """

    code =
      convert("""
      <img src="{{ String.upcase("abc") }}">
      """)

    assert code == """
           <img src={"\#{String.upcase("abc")}"}>
           """

    code =
      convert("""
      <div id="id_{{@id1}}_{{ @id2 }}">
        <div id=
          "
          id_{{@id}}
        ">
        </div>
      </div>
      """)

    assert code == """
           <div id={"id_\#{@id1}_\#{@id2}"}>
             <div id=
               {"
               id_\#{@id}
             "}>
             </div>
           </div>
           """
  end

  test ~S(replace ~H""" with ~F""") do
    code = """
    ~H"\""
    <Link label="elixir" to={{url}} />
    "\""

    ~H"\""
    <Link label="elixir" to={{url}} />
    "\""
    """

    assert Convert.convert_file_contents!("nofile.ex", code) === """
           ~F"\""
           <Link label="elixir" to={url} />
           "\""

           ~F"\""
           <Link label="elixir" to={url} />
           "\""
           """
  end

  test ~S(replace ~H" with ~F") do
    code = """
    ~H"<Link label='elixir' to={{url}} />"

    ~H"<Link label='elixir' to={{url}} />"
    """

    assert Convert.convert_file_contents!("nofile.ex", code) === """
           ~F"<Link label='elixir' to={url} />"

           ~F"<Link label='elixir' to={url} />"
           """
  end

  test "replace ~H[ with ~F[" do
    code = """
    ~H[<Link label="elixir" to={{url}} />]

    ~H[<Link label="elixir" to={{url}} />]
    """

    assert Convert.convert_file_contents!("nofile.ex", code) === """
           ~F[<Link label="elixir" to={url} />]

           ~F[<Link label="elixir" to={url} />]
           """
  end

  test "replace ~H( with ~F(" do
    code = """
    ~H(<Link label="elixir" to={{url}} />)

    ~H(<Link label="elixir" to={{url}} />)
    """

    assert Convert.convert_file_contents!("nofile.ex", code) === """
           ~F(<Link label="elixir" to={url} />)

           ~F(<Link label="elixir" to={url} />)
           """
  end

  test "replace ~H{ with ~F{" do
    code = """
    ~H{<slot name="header" />}

    ~H{<slot name="footer" />}
    """

    assert Convert.convert_file_contents!("nofile.ex", code) === """
           ~F{<#slot name="header" />}

           ~F{<#slot name="footer" />}
           """
  end

  test "convert {{# comment }} into {!-- comment --}" do
    code =
      convert("""
      {{#comment}}
      {{# comment}}
      {{ # comment }}
      """)

    assert code == """
           {!-- comment --}
           {!-- comment --}
           {!-- comment --}
           """
  end

  test "convert slot's :props into :args" do
    code =
      convert("""
      <div :props=""/>
      <slot :props=""/>
      <div :props=""/>
      """)

    assert code == """
           <div :props=""/>
           <#slot :args=""/>
           <div :props=""/>
           """
  end

  test "ErrorTag phx_feedback_for into feedback_for" do
    code =
      convert("""
      <ErrorTag phx_feedback_for="hello" />
      """)

    assert code == """
           <ErrorTag feedback_for="hello" />
           """
  end
end
