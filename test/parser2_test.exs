defmodule Surface.Compiler.Parser2Test do
  use ExUnit.Case, async: true

  import Surface.Compiler.Parser

  test "empty node" do
    assert parse("") == {:ok, []}
  end

  test "only text" do
    assert parse("Some text") == {:ok, ["Some text"]}
  end

  test "keep spaces before node" do
    assert parse("\n<div></div>") ==
             {:ok,
              [
                "\n",
                {"div", [], [], %{line: 2}}
              ]}
  end

  test "keep spaces after node" do
    assert parse("<div></div>\n") ==
             {:ok,
              [
                {"div", [], [], %{line: 1}},
                "\n"
              ]}
  end

  test "keep blank chars" do
    assert parse("\n\r\t\v\b\f\e\d\a") == {:ok, ["\n\r\t\v\b\f\e\d\a"]}
  end

  test "multiple nodes" do
    code = """
    <div>
      Div 1
    </div>
    <div>
      Div 2
    </div>
    """

    assert parse(code) ==
             {:ok,
              [
                {"div", [], ["\n  Div 1\n"], %{line: 1}},
                "\n",
                {"div", [], ["\n  Div 2\n"], %{line: 4}},
                "\n"
              ]}
  end

  test "text before and after" do
    assert parse("hello<foo>bar</foo>world") ==
             {:ok, ["hello", {"foo", [], ["bar"], %{line: 1}}, "world"]}
  end

  test "component" do
    code = ~S(<MyComponent label="My label"/>)
    {:ok, [node]} = parse(code)

    assert node ==
             {"MyComponent",
              [
                {"label", "My label", %{line: 1}}
              ], [], %{line: 1}}
  end

  test "slot shorthand" do
    code = ~S(<:footer :let={ a: 1 }/>)
    {:ok, [node]} = parse(code)

    assert {":footer", [{":let", _, _}], [], _} = node
  end

  test "spaces and line break between children" do
    code = """
    <div>
      <span/> <span/>
      <span/>
    </div>
    """

    {:ok, tree} = parse(code)

    assert tree == [
             {
               "div",
               '',
               [
                 "\n  ",
                 {"span", '', '', %{line: 2}},
                 " ",
                 {"span", [], [], %{line: 2}},
                 "\n  ",
                 {"span", [], [], %{line: 3}},
                 "\n"
               ],
               %{line: 1}
             },
             "\n"
           ]
  end

  test "comments" do
    code = """
    <div>
    <!--
    This is
    a comment
    -->
      <span/>
    </div>
    """

    {:ok, [{"div", _, [_, {:comment, comment}, _, {"span", _, _, _}, _], _}, _]} = parse(code)

    assert comment == """
           <!--
           This is
           a comment
           -->\
           """
  end

  describe "void elements" do
    test "without attributes" do
      code = """
      <div>
        <hr>
      </div>
      """

      {:ok, [{"div", [], ["\n  ", node, "\n"], _}, "\n"]} = parse(code)
      assert node == {"hr", [], [], %{line: 2}}
    end

    test "with attributes" do
      code = """
      <div>
        <img
          src="file.gif"
          alt="My image"
        >
      </div>
      """

      {:ok, [{"div", [], ["\n  ", node, "\n"], _}, "\n"]} = parse(code)

      assert node ==
               {"img",
                [
                  {"src", "file.gif", %{line: 3}},
                  {"alt", "My image", %{line: 4}}
                ], [], %{line: 2}}
    end
  end

  describe "HTML only" do
    test "single node" do
      assert parse("<foo>bar</foo>") ==
               {:ok, [{"foo", [], ["bar"], %{line: 1}}]}
    end

    test "Elixir node" do
      assert parse("<Foo.Bar>bar</Foo.Bar>") ==
               {:ok, [{"Foo.Bar", [], ["bar"], %{line: 1}}]}
    end

    test "mixed nodes" do
      assert parse("<foo>one<bar>two</bar>three</foo>") ==
               {:ok,
                [
                  {"foo", [], ["one", {"bar", [], ["two"], %{line: 1}}, "three"], %{line: 1}}
                ]}
    end

    test "self-closing nodes" do
      assert parse("<foo>one<bar><bat/></bar>three</foo>") ==
               {:ok,
                [
                  {"foo", [],
                   [
                     "one",
                     {"bar", [], [{"bat", [], [], %{line: 1}}], %{line: 1}},
                     "three"
                   ], %{line: 1}}
                ]}
    end
  end

  describe "interpolation" do
    test "as root" do
      assert parse("{baz}") ==
               {:ok, [{:interpolation, "baz", %{line: 1}}]}
    end

    test "with curlies embedded" do
      assert parse("{ {1, 3} }") ==
               {:ok, [{:interpolation, " {1, 3} ", %{line: 1}}]}
    end

    test "with deeply nested curlies" do
      assert parse("{{{{{{{{{{{}}}}}}}}}}}") ==
               {:ok, [{:interpolation, "{{{{{{{{{{}}}}}}}}}}", %{line: 1}}]}
    end

    test "matched curlies for a map expression" do
      assert parse("{ %{a: %{b: 1}} }") ==
               {:ok, [{:interpolation, " %{a: %{b: 1}} ", %{line: 1}}]}
    end

    test "tuple without spaces between enclosing curlies" do
      assert parse("{{:a, :b}}") ==
               {:ok, [{:interpolation, "{:a, :b}", %{line: 1}}]}
    end

    test "without root node but with text" do
      assert parse("foo {baz} bar") ==
               {:ok, ["foo ", {:interpolation, "baz", %{line: 1}}, " bar"]}
    end

    test "with root node" do
      assert parse("<foo>{baz}</foo>") ==
               {:ok, [{"foo", '', [{:interpolation, "baz", %{line: 1}}], %{line: 1}}]}
    end

    test "mixed curly bracket" do
      assert parse("<foo>bar{baz}bat</foo>") ==
               {:ok,
                [
                  {"foo", '', ["bar", {:interpolation, "baz", %{line: 1}}, "bat"], %{line: 1}}
                ]}
    end

    #  test "single-closing curly bracket" do
    #    assert parse("<foo>bar{ 'a}b' }bat</foo>") ==
    #             {:ok,
    #              [
    #                {"foo", [], ["bar", {:interpolation, " 'a}b' ", %{line: 1}}, "bat"],
    #                 %{line: 1}}
    #              ]}
    #  end

    #  test "charlist with closing curly in tuple" do
    #    assert parse("{{ 'a}}b' }}") ==
    #             {:ok, [{:interpolation, " 'a}}b' ", %{line: 1}}]}
    #  end

    #   test "binary with closing curly in tuple" do
    #     assert parse("{{ {{'a}}b'}} }}") ==
    #              {:ok, [{:interpolation, " {{'a}}b'}} ", %{line: 1}}]}
    #   end

    #   test "double closing curly brace inside charlist" do
    #     assert parse("{{ {{\"a}}b\"}} }}") ==
    #              {:ok, [{:interpolation, " {{\"a}}b\"}} ", %{line: 1}}]}
    #   end

    #   test "double closing curly brace inside binary" do
    #     assert parse("{{ \"a}}b\" }}") ==
    #              {:ok, [{:interpolation, " \"a}}b\" ", %{line: 1}}]}
    #   end

    #   test "single-opening curly bracket inside single quotes" do
    #     assert parse("{{ 'a{b' }}") ==
    #              {:ok, [{:interpolation, " 'a{b' ", %{line: 1}}]}
    #   end

    #   test "single-opening curly bracket inside double quotes" do
    #     assert parse("{{ \"a{b\" }}") ==
    #              {:ok, [{:interpolation, " \"a{b\" ", %{line: 1}}]}
    #   end

    test "containing a charlist with escaped single quote" do
      assert parse("{ 'a\\'b' }") ==
               {:ok, [{:interpolation, " 'a\\'b' ", %{line: 1}}]}
    end

    test "containing a binary with escaped double quote" do
      assert parse("{ \"a\\\"b\" }") ==
               {:ok, [{:interpolation, " \"a\\\"b\" ", %{line: 1}}]}
    end

    test "nested multi-element tuples" do
      assert parse("""
             { {a, {b, c}} <- [{"a", {"b", "c"}}]}
             """) ==
               {:ok,
                [{:interpolation, " {a, {b, c}} <- [{\"a\", {\"b\", \"c\"}}]", %{line: 1}}, "\n"]}
    end
  end

  describe "with macros" do
    test "single node" do
      assert parse("<#Foo>bar</#Foo>") ==
               {:ok, [{"#Foo", [], ["bar"], %{line: 1}}]}
    end

    test "mixed nodes" do
      assert parse("<#Foo>one<bar>two</baz>three</#Foo>") ==
               {:ok, [{"#Foo", [], ["one<bar>two</baz>three"], %{line: 1}}]}

      assert parse("<#Foo>one<#bar>two</#baz>three</#Foo>") ==
               {:ok, [{"#Foo", [], ["one<#bar>two</#baz>three"], %{line: 1}}]}

      assert parse("<#Foo>one<bar>two<baz>three</#Foo>") ==
               {:ok, [{"#Foo", [], ["one<bar>two<baz>three"], %{line: 1}}]}

      assert parse("<#Foo>one</bar>two</baz>three</#Foo>") ==
               {:ok, [{"#Foo", [], ["one</bar>two</baz>three"], %{line: 1}}]}
    end

    test "macro issue" do
      assert parse("<#Macro/>") ==
               {:ok, [{"#Macro", '', [], %{line: 1}}]}
    end

    test "keep track of the line of the definition" do
      code = """
      <div>
        one
        <#Foo>
          two
        </#Foo>
      </div>
      """

      {:ok, [{_, _, children, _} | _]} = parse(code)
      {_, _, _, meta} = Enum.at(children, 1)
      assert meta.line == 3
    end

    test "do not perform interpolation for inner content" do
      assert parse("<#Foo>one {@var} two</#Foo>") ==
               {:ok, [{"#Foo", [], ["one {@var} two"], %{line: 1}}]}
    end
  end

  describe "errors on" do
    test "expected tag name" do
      assert parse("""
             text
             <>bar</>
             """) == {:error, "expected tag name", 2}
    end

    test "invalid closing tag" do
      assert parse("<foo>bar</a></foo>") ==
               {:error, "expected closing tag for <foo>", 1}
    end

    test "missing closing tag" do
      code = "<foo><bar></foo>"
      assert parse(code) == {:error, "expected closing tag for <bar>", 1}

      code = "<foo><Bar></foo>"
      assert parse(code) == {:error, "expected closing tag for <Bar>", 1}

      code = "<foo><Bar.Baz></foo>"
      assert parse(code) == {:error, "expected closing tag for <Bar.Baz>", 1}

      code = "<foo><Bar1></foo>"
      assert parse(code) == {:error, "expected closing tag for <Bar1>", 1}

      code = "<foo><Bar_1></foo>"
      assert parse(code) == {:error, "expected closing tag for <Bar_1>", 1}

      code = "<foo><bar-baz></foo>"
      assert parse(code) == {:error, "expected closing tag for <bar-baz>", 1}

      code = "<foo><#Bar></foo>"
      assert parse(code) == {:error, "expected closing tag for <#Bar>", 1}

      code = """
      <foo>
        text before
        <div attr1="1" attr="2">
        text after
      </foo>
      """

      assert parse(code) == {:error, "expected closing tag for <div>", 3}
    end

    test "tag mismatch" do
      assert parse("<foo>bar</baz>") ==
               {:error, "expected closing tag for <foo>", 1}
    end

    test "incomplete tag content" do
      assert parse("<foo>bar") ==
               {:error, "expected closing tag for <foo>", 1}
    end

    test "incomplete macro content" do
      assert parse("<#foo>bar</#bar>") ==
               {:error, "expected closing tag for <#foo>", 1}
    end

    test "non-closing interpolation" do
      assert parse("<foo>{bar</foo>") ==
               {:error, "expected closing `}` for expression", 1}
    end

    test "non-matched curlies inside interpolation" do
      assert parse("<foo>{bar { }</foo>") ==
               {:error, "expected closing `}` for expression", 1}
    end
  end

  describe "attributes" do
    test "keep blank chars between attributes" do
      code = """
      <foo prop1="1"\n\r\t\fprop2="2"/>\
      """

      {:ok, [{_, attributes, _, _}]} = parse(code)

      assert attributes == [
               {"prop1", "1", %{line: 1}},
               {"prop2", "2", %{line: 2}}
             ]
    end

    test "regular nodes" do
      code = """
      <foo
        prop1="value1"
        prop2="value2"
      >
        bar
        <div>{ var }</div>
      </foo>
      """

      attributes = [
        {"prop1", "value1", %{line: 2}},
        {"prop2", "value2", %{line: 3}}
      ]

      children = [
        "\n  bar\n  ",
        {"div", [], [{:interpolation, " var ", %{line: 6}}], %{line: 6}},
        "\n"
      ]

      assert parse(code) == {:ok, [{"foo", attributes, children, %{line: 1}}, "\n"]}
    end

    test "self-closing nodes" do
      code = """
      <foo
        prop1="value1"
        prop2="value2"
      />
      """

      attributes = [
        {"prop1", "value1", %{line: 2}},
        {"prop2", "value2", %{line: 3}}
      ]

      assert parse(code) == {:ok, [{"foo", attributes, [], %{line: 1}}, "\n"]}
    end

    test "macro nodes" do
      code = """
      <#foo
        prop1="value1"
        prop2="value2"
      >
        bar
      </#foo>
      """

      attributes = [
        {"prop1", "value1", %{line: 2}},
        {"prop2", "value2", %{line: 3}}
      ]

      assert parse(code) ==
               {:ok, [{"#foo", attributes, ["\n  bar\n"], %{line: 1}}, "\n"]}
    end

    test "regular nodes with whitespaces" do
      code = """
      <foo
        prop1
        prop2 = "value 2"
        prop3 =
          { var3 }
        prop4
      ></foo>
      """

      attributes = [
        {"prop1", true, %{line: 2}},
        {"prop2", "value 2", %{line: 3}},
        {"prop3", {:attribute_expr, " var3 ", %{line: 5}}, %{line: 4}},
        {"prop4", true, %{line: 6}}
      ]

      assert parse(code) == {:ok, [{"foo", attributes, [], %{line: 1}}, "\n"]}
    end

    test "self-closing nodes with whitespaces" do
      code = """
      <foo
        prop1
        prop2 = "2"
        prop3 =
          { var3 }
        prop4
      />
      """

      attributes = [
        {"prop1", true, %{line: 2}},
        {"prop2", "2", %{line: 3}},
        {"prop3", {:attribute_expr, " var3 ", %{line: 5}}, %{line: 4}},
        {"prop4", true, %{line: 6}}
      ]

      assert parse(code) == {:ok, [{"foo", attributes, [], %{line: 1}}, "\n"]}
    end

    test "value as expression" do
      code = """
      <foo
        prop1={ var1 }
        prop2={ var2 }
      />
      """

      attributes = [
        {"prop1", {:attribute_expr, " var1 ", %{line: 2}}, %{line: 2}},
        {"prop2", {:attribute_expr, " var2 ", %{line: 3}}, %{line: 3}}
      ]

      assert parse(code) == {:ok, [{"foo", attributes, [], %{line: 1}}, "\n"]}
    end

    test "integer values" do
      code = """
      <foo
        prop1=1
        prop2=2
      />
      """

      attributes = [
        {"prop1", 1, %{line: 2}},
        {"prop2", 2, %{line: 3}}
      ]

      assert parse(code) == {:ok, [{"foo", attributes, [], %{line: 1}}, "\n"]}
    end

    test "boolean values" do
      code = """
      <foo
        prop1
        prop2=true
        prop3=false
        prop4
      />
      """

      attributes = [
        {"prop1", true, %{line: 2}},
        {"prop2", true, %{line: 3}},
        {"prop3", false, %{line: 4}},
        {"prop4", true, %{line: 5}}
      ]

      assert parse(code) == {:ok, [{"foo", attributes, [], %{line: 1}}, "\n"]}
    end

    test "string values" do
      code = """
      <foo prop="str"/>
      """

      attr_value = "str"

      attributes = [
        {"prop", attr_value, %{line: 1}}
      ]

      assert parse(code) == {:ok, [{"foo", attributes, [], %{line: 1}}, "\n"]}
    end

    test "empty string" do
      code = """
      <foo prop=""/>
      """

      attr_value = ""

      attributes = [
        {"prop", attr_value, %{line: 1}}
      ]

      assert parse(code) == {:ok, [{"foo", attributes, [], %{line: 1}}, "\n"]}
    end

    # test "string with embedded interpolation" do
    #   code = """
    #   <foo prop="before { var } after"/>
    #   """

    #   attr_value = ["before ", {:attribute_expr, " var ", %{line: 1}}, " after"]

    #   attributes = [
    #     {"prop", attr_value, %{line: 1}}
    #   ]

    #   assert parse(code) == {:ok, [{"foo", attributes, [], %{line: 1}}, "\n"]}
    # end

    #   test "string with only an embedded interpolation" do
    #     code = """
    #     <foo prop="{ var }"/>
    #     """

    #     attr_value = [{:attribute_expr, " var ", %{line: 1}}]

    #     attributes = [
    #       {"prop", attr_value, %{line: 1}}
    #     ]

    #     assert parse(code) == {:ok, [{"foo", attributes, [], %{line: 1}}, "\n"]}
    #   end

    test "interpolation with nested curlies" do
      code = """
      <foo prop={ {{}} }/>
      """

      attr_value = {:attribute_expr, " {{}} ", %{line: 1}}

      attributes = [
        {"prop", attr_value, %{line: 1}}
      ]

      assert parse(code) == {:ok, [{"foo", attributes, [], %{line: 1}}, "\n"]}
    end

    test "attribute expression with nested tuples" do
      code = """
      <li :for={ {a, {b, c}} <- [{"a", {"b", "c"}}]} />
      """

      attr_value = {:attribute_expr, " {a, {b, c}} <- [{\"a\", {\"b\", \"c\"}}]", %{line: 1}}

      attributes = [
        {":for", attr_value, %{line: 1}}
      ]

      assert parse(code) ==
               {:ok, [{"li", attributes, [], %{line: 1}}, "\n"]}
    end
  end

  describe "sub-blocks" do
    test "single sub-block" do
      code = """
      <#if {true}>
        1
      <#else>
        2
      </#if>\
      """

      assert parse(code) ==
               {:ok,
                [
                  {"#if", [{:root, {:attribute_expr, "true", %{line: 1}}, %{line: 1}}],
                   [
                     {:default, [], ["\n  1\n"], %{}},
                     {"#else", [], ["\n  2\n"], %{line: 3}}
                   ], %{line: 1, has_sub_blocks?: true}}
                ]}
    end

    test "multiple sub-blocks" do
      code = """
      <#if {true}>
        1
      <#elseif>
        2
      <#elseif>
        3
      <#else>
        4
      </#if>\
      """

      assert parse(code) ==
               {:ok,
                [
                  {"#if", [{:root, {:attribute_expr, "true", %{line: 1}}, %{line: 1}}],
                   [
                     {:default, [], ["\n  1\n"], %{}},
                     {"#elseif", [], ["\n  2\n"], %{line: 3}},
                     {"#elseif", [], ["\n  3\n"], %{line: 5}},
                     {"#else", [], ["\n  4\n"], %{line: 7}}
                   ], %{line: 1, has_sub_blocks?: true}}
                ]}
    end

    test "nested sub-blocks" do
      code = """
      <#if {1}>
        111
      <#elseif {2}>
        222
        <#if {3}>
          333
        <#else>
          444
        </#if>
      <#else>
        555
      </#if>\
      """

      assert parse(code) ==
               {:ok,
                [
                  {"#if", [{:root, {:attribute_expr, "1", %{line: 1}}, %{line: 1}}],
                   [
                     {:default, [], ["\n  111\n"], %{}},
                     {"#elseif", [{:root, {:attribute_expr, "2", %{line: 3}}, %{line: 3}}],
                      [
                        "\n  222\n  ",
                        {"#if", [{:root, {:attribute_expr, "3", %{line: 5}}, %{line: 5}}],
                         [
                           {:default, [], ["\n    333\n  "], %{}},
                           {"#else", [], ["\n    444\n  "], %{line: 7}}
                         ], %{has_sub_blocks?: true, line: 5}},
                        "\n"
                      ], %{line: 3}},
                     {"#else", [], ["\n  555\n"], %{line: 10}}
                   ], %{has_sub_blocks?: true, line: 1}}
                ]}
    end

    test "handle invalid parents for #else" do
      code = """
      <div>
      <#else>
      </div>
      """

      assert parse(code) ==
               {:error,
                "cannot use <#else> inside <div>. Possible parents are \"<#if>\" and \"<#for>\"",
                2}
    end

    test "handle invalid parents for #elseif" do
      code = """
      <div>
      <#elseif>
      </div>
      """

      assert parse(code) ==
               {:error,
                "cannot use <#elseif> inside <div>. The <#elseif> construct can only be used inside a \"<#if>\"",
                2}
    end

    test "handle invalid parents for #match" do
      code = """
      <div>
      <#match>
      </div>
      """

      assert parse(code) ==
               {:error,
                "cannot use <#match> inside <div>. The <#match> construct can only be used inside a \"<#case>\"",
                2}
    end

    test "raise error on sub-blocks without parent node" do
      code = """
        1
      <#else>
        2
      """

      assert parse(code) ==
               {:error,
                "no valid parent node defined for <#else>. Possible parents are \"<#if>\" and \"<#for>\"",
                2}
    end
  end
end
