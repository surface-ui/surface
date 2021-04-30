defmodule Surface.Compiler.Converter_0_5Test do
  use ExUnit.Case, async: true

  alias Surface.Compiler.Converter
  alias Surface.Compiler.Converter_0_5

  defp convert(text) do
    Converter.convert(text, converter: Converter_0_5)
  end

  test "don't convert code inside macros" do
    expected =
      convert("""
      <div class={{ @class }}>text</div>
      <#Raw>
        <div class={{ @class }}>text</div>
      </#Raw>
      """)

    assert expected == """
           <div class={@class}>text</div>
           <#Raw>
             <div class={{ @class }}>text</div>
           </#Raw>
           """
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
             id={@id}   class={@class}
             phone = {@phone}
           >
             <span title={123} />
             1{@name}2 3{@name}4
                 5 {@value} 6
           7 </div>
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
           <div disabled={true}>
             1
           </div>
           <div
             tabindex={2}>2</div>
           """
  end

  ## Planned changes. Uncomment as the related implementation gets merged

  # test "convert <template> into <#template>" do
  #   expected =
  #     convert("""
  #     <div>
  #       <template slot="footer">
  #         Footer
  #       </template>
  #     </div>
  #     """)

  #   assert expected == """
  #          <div>
  #            <#template slot="footer">
  #              Footer
  #            </#template>
  #          </div>
  #          """
  # end

  # test "convert <slot> into <#slot>" do
  #   expected =
  #     convert("""
  #     <div>
  #       <slot name="footer">
  #         Footer
  #       </slot>
  #     </div>
  #     """)

  #   assert expected == """
  #          <div>
  #            <#slot name="footer">
  #              Footer
  #            </#slot>
  #          </div>
  #          """
  # end

  # test "convert <If> into <#if>" do
  #   expected =
  #     convert("""
  #     <div>
  #       <If condition={{ @var }}>
  #         1
  #         </If>
  #       <If   condition={{@var}}>2</If>
  #     </div>
  #     """)

  #   assert expected == """
  #          <div>
  #            <#if condition={@var}>
  #              1
  #              </#if>
  #            <#if   condition={@var}>2</#if>
  #          </div>
  #          """
  # end

  # test "convert <For> into <#For>" do
  #   expected =
  #     convert("""
  #     <div>
  #       <For each={{ _i <- @var }}>
  #         1
  #         </For>
  #       <For   each={{@var}}>2</For>
  #     </div>
  #     """)

  #   assert expected == """
  #          <div>
  #            <#for each={_i <- @var}>
  #              1
  #              </#for>
  #            <#for   each={@var}>2</#for>
  #          </div>
  #          """
  # end

  # test "convert slot's :props into :args" do
  #   expected =
  #     convert("""
  #     <div :props=""/>
  #     <#slot :props=""/>
  #     <div :props=""/>
  #     """)

  #   assert expected == """
  #          <div :props=""/>
  #          <#slot args=""/>
  #          <div :props=""/>
  #          """
  # end
end
