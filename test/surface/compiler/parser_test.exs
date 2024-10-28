defmodule Surface.Compiler.ParserTest do
  use Surface.Case, async: true

  import Surface.Compiler.Parser
  alias Surface.Compiler.ParseError

  test "empty node" do
    assert parse!("") == []
  end

  test "only text" do
    assert parse!("Some text") == ["Some text"]
  end

  test "keep spaces before node" do
    assert [
             "\n",
             {"div", [], [], %{line: 2, file: "nofile", column: 2}}
           ] = parse!("\n<div></div>")
  end

  test "keep spaces after node" do
    assert [
             {"div", [], [], %{line: 1, file: "nofile", column: 2}},
             "\n"
           ] = parse!("<div></div>\n")
  end

  test "keep blank chars" do
    assert parse!("\n\r\t\v\b\f\e\d\a") == ["\n\r\t\v\b\f\e\d\a"]
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

    assert [
             {"div", [], ["\n  Div 1\n"], %{line: 1, file: "nofile", column: 2}},
             "\n",
             {"div", [], ["\n  Div 2\n"], %{line: 4, file: "nofile", column: 2}},
             "\n"
           ] = parse!(code)
  end

  test "text before and after" do
    assert ["hello", {"foo", [], ["bar"], %{line: 1, file: "nofile", column: 7}}, "world"] =
             parse!("hello<foo>bar</foo>world")
  end

  test "component" do
    code = ~S(<MyComponent label="My label"/>)
    [node] = parse!(code)

    assert node ==
             {"MyComponent",
              [
                {"label", "My label", %{line: 1, file: "nofile", column: 14}}
              ], [], %{line: 1, file: "nofile", column: 2, decomposed_tag: {:component, MyComponent, nil}}}
  end

  test "slot shorthand" do
    code = ~S(<:footer :let={ a: 1 }/>)
    [node] = parse!(code)

    assert {":footer", [{":let", _, _}], [], _} = node
  end

  test "spaces and line break between children" do
    code = """
    <div>
      <span/> <span/>
      <span/>
    </div>
    """

    tree = parse!(code)

    assert [
             {
               "div",
               ~c"",
               [
                 "\n  ",
                 {"span", ~c"", ~c"", %{line: 2, file: "nofile", column: 4}},
                 " ",
                 {"span", [], [], %{line: 2, file: "nofile", column: 12}},
                 "\n  ",
                 {"span", [], [], %{line: 3, file: "nofile", column: 4}},
                 "\n"
               ],
               %{line: 1, file: "nofile", column: 2}
             },
             "\n"
           ] = tree
  end

  test "public comments" do
    code = """
    <div>
    <!--
    This is
    a comment
    -->
      <span/>
    </div>
    """

    [{"div", _, [_, {:comment, comment, %{visibility: :public}}, _, {"span", _, _, _}, _], _}, _] = parse!(code)

    assert comment == """
           <!--
           This is
           a comment
           -->\
           """
  end

  test "private comments" do
    code = """
    <div>
    {!--
    This is
    a comment
    --}
      <span/>
    </div>
    """

    [{"div", _, [_, {:comment, comment, %{visibility: :private}}, _, {"span", _, _, _}, _], _}, _] = parse!(code)

    assert comment == """
           {!--
           This is
           a comment
           --}\
           """
  end

  describe "void elements" do
    test "without attributes" do
      code = """
      <div>
        <hr>
      </div>
      """

      [{"div", [], ["\n  ", node, "\n"], _}, "\n"] = parse!(code)
      assert {"hr", [], [], %{line: 2, file: "nofile", column: 4, void_tag?: true}} = node
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

      [{"div", [], ["\n  ", node, "\n"], _}, "\n"] = parse!(code)

      assert {"img",
              [
                {"src", "file.gif", %{line: 3, file: "nofile", column: 5}},
                {"alt", "My image", %{line: 4, file: "nofile", column: 5}}
              ], [], %{line: 2, file: "nofile", column: 4, void_tag?: true}} = node
    end
  end

  describe "HTML only" do
    test "single node" do
      assert [{"foo", [], ["bar"], %{line: 1, file: "nofile", column: 2}}] = parse!("<foo>bar</foo>")
    end

    test "Elixir node" do
      assert [{"Foo.Bar", [], ["bar"], %{line: 1, file: "nofile", column: 2}}] = parse!("<Foo.Bar>bar</Foo.Bar>")
    end

    test "mixed nodes" do
      assert [
               {"foo", [], ["one", {"bar", [], ["two"], %{line: 1, file: "nofile", column: 10}}, "three"],
                %{line: 1, file: "nofile", column: 2}}
             ] = parse!("<foo>one<bar>two</bar>three</foo>")
    end

    test "self-closing nodes" do
      assert [
               {"foo", [],
                [
                  "one",
                  {"bar", [], [{"bat", [], [], %{line: 1, file: "nofile", column: 15}}],
                   %{line: 1, file: "nofile", column: 10}},
                  "three"
                ], %{line: 1, file: "nofile", column: 2}}
             ] = parse!("<foo>one<bar><bat/></bar>three</foo>")
    end
  end

  describe "expressions" do
    test "as root" do
      assert parse!("{baz}") ==
               [{:expr, "baz", %{line: 1, file: "nofile", column: 2}}]
    end

    test "with curlies embedded" do
      assert parse!("{ {1, 3} }") ==
               [{:expr, " {1, 3} ", %{line: 1, file: "nofile", column: 2}}]
    end

    test "with deeply nested curlies" do
      assert parse!("{{{{{{{{{{{}}}}}}}}}}}") ==
               [{:expr, "{{{{{{{{{{}}}}}}}}}}", %{line: 1, file: "nofile", column: 2}}]
    end

    test "matched curlies for a map expression" do
      assert parse!("{ %{a: %{b: 1}} }") ==
               [{:expr, " %{a: %{b: 1}} ", %{line: 1, file: "nofile", column: 2}}]
    end

    test "tuple without spaces between enclosing curlies" do
      assert parse!("{{:a, :b}}") ==
               [{:expr, "{:a, :b}", %{line: 1, file: "nofile", column: 2}}]
    end

    test "without root node but with text" do
      assert parse!("foo {baz} bar") ==
               ["foo ", {:expr, "baz", %{line: 1, file: "nofile", column: 6}}, " bar"]
    end

    test "with root node" do
      assert [
               {"foo", ~c"", [{:expr, "baz", %{line: 1, file: "nofile", column: 7}}],
                %{line: 1, file: "nofile", column: 2}}
             ] = parse!("<foo>{baz}</foo>")
    end

    test "mixed curly bracket" do
      assert [
               {"foo", ~c"",
                [
                  "bar",
                  {:expr, "baz", %{line: 1, file: "nofile", column: 10}},
                  "bat"
                ], %{line: 1, file: "nofile", column: 2}}
             ] = parse!("<foo>bar{baz}bat</foo>")
    end

    test "containing a charlist with escaped single quote" do
      assert parse!("{ 'a\\'b' }") ==
               [{:expr, " 'a\\'b' ", %{line: 1, file: "nofile", column: 2}}]
    end

    test "containing a binary with escaped double quote" do
      assert parse!("{ \"a\\\"b\" }") ==
               [{:expr, " \"a\\\"b\" ", %{line: 1, file: "nofile", column: 2}}]
    end

    test "nested multi-element tuples" do
      assert parse!("""
             { {a, {b, c}} <- [{"a", {"b", "c"}}]}
             """) ==
               [
                 {:expr, " {a, {b, c}} <- [{\"a\", {\"b\", \"c\"}}]", %{line: 1, file: "nofile", column: 2}},
                 "\n"
               ]
    end
  end

  describe "with macros" do
    test "single node" do
      assert parse!("<#Foo>bar</#Foo>") ==
               [{"#Foo", [], ["bar"], %{line: 1, file: "nofile", column: 2}}]
    end

    test "mixed nodes" do
      assert parse!("<#Foo>one<bar>two</baz>three</#Foo>") ==
               [{"#Foo", [], ["one<bar>two</baz>three"], %{line: 1, file: "nofile", column: 2}}]
    end

    test "inner text has macro-like tag" do
      assert parse!("<#Foo>one<#bar>two</#baz>three</#Foo>") ==
               [
                 {"#Foo", [], ["one<#bar>two</#baz>three"], %{line: 1, file: "nofile", column: 2}}
               ]
    end

    test "inner text has only open tags (invalid html)" do
      assert parse!("<#Foo>one<bar>two<baz>three</#Foo>") ==
               [{"#Foo", [], ["one<bar>two<baz>three"], %{line: 1, file: "nofile", column: 2}}]
    end

    test "inner text has all closing tags (invalid html)" do
      assert parse!("<#Foo>one</bar>two</baz>three</#Foo>") ==
               [{"#Foo", [], ["one</bar>two</baz>three"], %{line: 1, file: "nofile", column: 2}}]
    end

    test "self-closing macro" do
      assert parse!("<#Macro/>") ==
               [{"#Macro", ~c"", [], %{line: 1, file: "nofile", column: 2}}]
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

      [{_, _, children, _} | _] = parse!(code)
      {_, _, _, meta} = Enum.at(children, 1)
      assert meta.line == 3
    end

    test "do not perform interpolation for inner content" do
      assert parse!("<#Foo>one {@var} two</#Foo>") ==
               [{"#Foo", [], ["one {@var} two"], %{line: 1, file: "nofile", column: 2}}]
    end
  end

  describe "errors on" do
    test "expected tag name" do
      code = """
      text
      <>bar</>
      """

      exception = assert_raise ParseError, fn -> parse!(code) end

      assert %ParseError{message: "expected tag name", line: 2} = exception
    end

    test "invalid closing tag" do
      code = "<foo>bar</a></foo>"

      exception = assert_raise ParseError, fn -> parse!(code) end

      message = "expected closing tag for <foo> defined on line 1, got </a>"

      assert %ParseError{message: ^message, line: 1} = exception
    end

    test "missing closing tag for html node" do
      code = "<foo><bar></foo>"

      exception = assert_raise ParseError, fn -> parse!(code) end

      message = "expected closing tag for <bar> defined on line 1, got </foo>"
      assert %ParseError{message: ^message, line: 1} = exception
    end

    test "missing closing tag for component node" do
      code = "<foo><Bar></foo>"

      exception = assert_raise ParseError, fn -> parse!(code) end

      message = "expected closing tag for <Bar> defined on line 1, got </foo>"
      assert %ParseError{message: ^message, line: 1} = exception
    end

    test "missing closing tag for fully specified component node" do
      code = "<foo><Bar.Baz></foo>"

      exception = assert_raise ParseError, fn -> parse!(code) end

      message = "expected closing tag for <Bar.Baz> defined on line 1, got </foo>"
      assert %ParseError{message: ^message, line: 1} = exception
    end

    test "missing closing tag for component node with number" do
      code = "<foo><Bar1></foo>"

      exception = assert_raise ParseError, fn -> parse!(code) end

      message = "expected closing tag for <Bar1> defined on line 1, got </foo>"
      assert %ParseError{message: ^message, line: 1} = exception
    end

    test "missing closing tag for component node with underscore and number" do
      code = "<foo><Bar_1></foo>"

      exception = assert_raise ParseError, fn -> parse!(code) end

      message = "expected closing tag for <Bar_1> defined on line 1, got </foo>"
      assert %ParseError{message: ^message, line: 1} = exception
    end

    test "missing closing tag for html node with dash" do
      code = "<foo><bar-baz></foo>"

      exception = assert_raise ParseError, fn -> parse!(code) end

      message = "expected closing tag for <bar-baz> defined on line 1, got </foo>"
      assert %ParseError{message: ^message, line: 1} = exception
    end

    test "missing closing tag for macro component node" do
      code = """
      <br>
      <foo><#Bar></foo>
      """

      exception = assert_raise ParseError, fn -> parse!(code) end

      message = "end of file reached without closing tag for <#Bar>"
      assert %ParseError{message: ^message, line: 2} = exception
    end

    test "missing closing tag for html node with surrounding text" do
      code = """
      <foo>
        text before
        <div attr1="1" attr="2">
        text after
      </foo>
      """

      exception = assert_raise ParseError, fn -> parse!(code) end

      message = "expected closing tag for <div> defined on line 3, got </foo>"
      assert %ParseError{message: ^message, line: 5} = exception
    end

    test "tag mismatch" do
      code = "<foo>bar</baz>"

      exception = assert_raise ParseError, fn -> parse!(code) end

      message = "expected closing tag for <foo> defined on line 1, got </baz>"
      assert %ParseError{message: ^message, line: 1} = exception
    end

    test "incomplete tag content" do
      code = """
      <br>
      <foo>bar
      """

      exception = assert_raise ParseError, fn -> parse!(code) end

      message = "end of file reached without closing tag for <foo>"
      assert %ParseError{message: ^message, line: 2} = exception
    end

    test "incomplete macro content" do
      code = "<#foo>bar</#bar>"

      exception = assert_raise ParseError, fn -> parse!(code) end

      message = "expected closing tag for <#foo> defined on line 1, got </#bar>"
      assert %ParseError{message: ^message, line: 1} = exception
    end
  end

  describe "attributes" do
    test "keep blank chars between attributes" do
      code = """
      <foo prop1="1"\n\r\t\fprop2="2"/>\
      """

      [{_, attributes, _, _}] = parse!(code)

      assert attributes == [
               {"prop1", "1", %{line: 1, file: "nofile", column: 6}},
               {"prop2", "2", %{line: 2, file: "nofile", column: 4}}
             ]
    end

    test "attribute values with single quote delimiter" do
      code = """
      <foo
        prop1='value1'
        prop2='value2'
      >
      </foo>
      """

      assert [{"foo", attributes, children, %{line: 1, file: "nofile", column: 2}}, "\n"] = parse!(code)

      assert [
               {"prop1", "value1", %{line: 2, file: "nofile", column: 3}},
               {"prop2", "value2", %{line: 3, file: "nofile", column: 3}}
             ] = attributes

      assert ["\n"] = children
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

      assert [{"foo", attributes, children, %{line: 1, file: "nofile", column: 2}}, "\n"] = parse!(code)

      assert [
               {"prop1", "value1", %{line: 2, file: "nofile", column: 3}},
               {"prop2", "value2", %{line: 3, file: "nofile", column: 3}}
             ] = attributes

      assert [
               "\n  bar\n  ",
               {"div", [], [{:expr, " var ", %{line: 6, file: "nofile", column: 9}}],
                %{line: 6, file: "nofile", column: 4}},
               "\n"
             ] = children
    end

    test "self-closing nodes" do
      code = """
      <foo
        prop1="value1"
        prop2="value2"
      />
      """

      attributes = [
        {"prop1", "value1", %{line: 2, file: "nofile", column: 3}},
        {"prop2", "value2", %{line: 3, file: "nofile", column: 3}}
      ]

      assert parse!(code) ==
               [{"foo", attributes, [], %{line: 1, file: "nofile", column: 2}}, "\n"]
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

      assert [{"#foo", attributes, ["\n  bar\n"], %{line: 1, file: "nofile", column: 2}}, "\n"] = parse!(code)

      assert attributes == [
               {"prop1", "value1", %{line: 2, file: "nofile", column: 3}},
               {"prop2", "value2", %{line: 3, file: "nofile", column: 3}}
             ]
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

      assert [{"foo", attributes, [], %{line: 1, file: "nofile", column: 2}}, "\n"] = parse!(code)

      assert attributes == [
               {"prop1", true, %{line: 2, file: "nofile", column: 3}},
               {"prop2", "value 2", %{line: 3, file: "nofile", column: 3}},
               {"prop3", {:attribute_expr, " var3 ", %{line: 5, file: "nofile", column: 6}},
                %{line: 4, file: "nofile", column: 3}},
               {"prop4", true, %{line: 6, file: "nofile", column: 3}}
             ]
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
        {"prop1", true, %{line: 2, file: "nofile", column: 3}},
        {"prop2", "2", %{line: 3, file: "nofile", column: 3}},
        {"prop3", {:attribute_expr, " var3 ", %{line: 5, file: "nofile", column: 6}},
         %{line: 4, file: "nofile", column: 3}},
        {"prop4", true, %{line: 6, file: "nofile", column: 3}}
      ]

      assert parse!(code) ==
               [{"foo", attributes, [], %{line: 1, file: "nofile", column: 2}}, "\n"]
    end

    test "value as expression" do
      code = """
      <foo
        prop1={ var1 }
        prop2={ var2 }
      />
      """

      attributes = [
        {"prop1", {:attribute_expr, " var1 ", %{line: 2, file: "nofile", column: 10}},
         %{line: 2, file: "nofile", column: 3}},
        {"prop2", {:attribute_expr, " var2 ", %{line: 3, file: "nofile", column: 10}},
         %{line: 3, file: "nofile", column: 3}}
      ]

      assert parse!(code) ==
               [{"foo", attributes, [], %{line: 1, file: "nofile", column: 2}}, "\n"]
    end

    test "no value is treated as true" do
      code = """
      <foo
        prop1
        prop2
      />
      """

      attributes = [
        {"prop1", true, %{line: 2, file: "nofile", column: 3}},
        {"prop2", true, %{line: 3, file: "nofile", column: 3}}
      ]

      assert parse!(code) ==
               [{"foo", attributes, [], %{line: 1, file: "nofile", column: 2}}, "\n"]
    end

    test "string values" do
      code = """
      <foo prop="str"/>
      """

      attr_value = "str"

      attributes = [
        {"prop", attr_value, %{line: 1, file: "nofile", column: 6}}
      ]

      assert parse!(code) ==
               [{"foo", attributes, [], %{line: 1, file: "nofile", column: 2}}, "\n"]
    end

    test "empty string" do
      code = """
      <foo prop=""/>
      """

      attr_value = ""

      attributes = [
        {"prop", attr_value, %{line: 1, file: "nofile", column: 6}}
      ]

      assert parse!(code) ==
               [{"foo", attributes, [], %{line: 1, file: "nofile", column: 2}}, "\n"]
    end

    test "interpolation with nested curlies" do
      code = """
      <foo prop={ {{}} }/>
      """

      attr_value = {:attribute_expr, " {{}} ", %{line: 1, file: "nofile", column: 12}}

      attributes = [
        {"prop", attr_value, %{line: 1, file: "nofile", column: 6}}
      ]

      assert parse!(code) ==
               [{"foo", attributes, [], %{line: 1, file: "nofile", column: 2}}, "\n"]
    end

    test "attribute expression with nested tuples" do
      code = """
      <li :for={ {a, {b, c}} <- [{"a", {"b", "c"}}]} />
      """

      attr_value =
        {:attribute_expr, " {a, {b, c}} <- [{\"a\", {\"b\", \"c\"}}]", %{line: 1, file: "nofile", column: 11}}

      attributes = [
        {":for", attr_value, %{line: 1, file: "nofile", column: 5}}
      ]

      assert parse!(code) ==
               [{"li", attributes, [], %{line: 1, file: "nofile", column: 2}}, "\n"]
    end

    test "shorthand notation for assigning attributes" do
      code = """
      <li
        {=id}
        {=@class}
        {=@phx_click_away}
      />
      """

      [{"li", attributes, [], _} | _] = parse!(code)

      assert [
               {"id", {:attribute_expr, "id", %{column: 5, line: 2}}, %{column: 4, line: 2}},
               {"class", {:attribute_expr, "@class", %{column: 5, line: 3}}, %{column: 4, line: 3}},
               {"phx-click-away", {:attribute_expr, "@phx_click_away", %{column: 5, line: 4}},
                %{column: 4, line: 4}}
             ] = attributes
    end

    test "shorthand notation for assigning props" do
      code = """
      <Component
        {=id}
        {=@class}
        {=@phx_click_away}
      />
      """

      [{"Component", attributes, [], _} | _] = parse!(code)

      assert [
               {"id", {:attribute_expr, "id", %{column: 5, line: 2}}, %{column: 4, line: 2}},
               {"class", {:attribute_expr, "@class", %{column: 5, line: 3}}, %{column: 4, line: 3}},
               {"phx_click_away", {:attribute_expr, "@phx_click_away", %{column: 5, line: 4}},
                %{column: 4, line: 4}}
             ] = attributes
    end

    test "raise on shorthand notation for assigning attributes with invalid expression " do
      code = """
      <li
        {=1}
      />
      """

      message = ~r"""
      nofile:2:
      #{maybe_ansi("error:")} invalid value for tagged expression `{=1}`. The expression must be either an assign or a variable.

      Examples: `<div {=@class}>` or `<div {=class}>`
      """

      assert_raise Surface.CompileError, message, fn -> parse!(code) end
    end

    test "raise on assigning {= ...} to an attribute" do
      code = """
      <li
        class={=@class}
      />
      """

      message = ~r"""
      nofile:2:
      #{maybe_ansi("error:")} cannot assign `{=@class}` to attribute `class`. \
      The tagged expression `{= }` can only be used on a root attribute/property.

      Example: <div {=@class}>
      """

      assert_raise Surface.CompileError, message, fn -> parse!(code) end
    end
  end

  describe "blocks" do
    test "without sub-blocks with nested child" do
      code = """
      {#if true}
        1
        <span>2</span>
        <span>3</span>
      {/if}\
      """

      assert [
               {:block, "if",
                [
                  {:root, {:attribute_expr, "true", %{line: 1, column: 6, file: "nofile"}},
                   %{line: 1, column: 6, file: "nofile"}}
                ],
                [
                  "\n  1\n  ",
                  {"span", [], ["2"], %{line: 3, column: 4, file: "nofile"}},
                  "\n  ",
                  {"span", [], ["3"], %{line: 4, column: 4, file: "nofile"}},
                  "\n"
                ], %{line: 1, column: 3, file: "nofile"}}
             ] = parse!(code)
    end

    test "single sub-block" do
      code = """
      {#if true}
        1
      {#else}
        2
      {/if}\
      """

      assert parse!(code) ==
               [
                 {:block, "if",
                  [
                    {:root, {:attribute_expr, "true", %{line: 1, file: "nofile", column: 6}},
                     %{line: 1, file: "nofile", column: 6}}
                  ],
                  [
                    {:block, :default, [], ["\n  1\n"], %{column: 3, file: "nofile", line: 1}},
                    {:block, "else", [], ["\n  2\n"], %{line: 3, file: "nofile", column: 3}}
                  ], %{line: 1, file: "nofile", column: 3, has_sub_blocks?: true}}
               ]
    end

    test "multiple sub-blocks" do
      code = """
      {#if true}
        1
      {#elseif}
        2
      {#elseif}
        3
      {#else}
        4
      {/if}\
      """

      assert parse!(code) ==
               [
                 {:block, "if",
                  [
                    {:root, {:attribute_expr, "true", %{line: 1, file: "nofile", column: 6}},
                     %{line: 1, file: "nofile", column: 6}}
                  ],
                  [
                    {:block, :default, [], ["\n  1\n"], %{column: 3, file: "nofile", line: 1}},
                    {:block, "elseif", [], ["\n  2\n"], %{line: 3, file: "nofile", column: 3}},
                    {:block, "elseif", [], ["\n  3\n"], %{line: 5, file: "nofile", column: 3}},
                    {:block, "else", [], ["\n  4\n"], %{line: 7, file: "nofile", column: 3}}
                  ], %{line: 1, file: "nofile", column: 3, has_sub_blocks?: true}}
               ]
    end

    test "nested sub-blocks" do
      code = """
      {#if 1}
        111
      {#elseif 2}
        222
        {#if 3}
          333
        {#else}
          444
        {/if}
      {#else}
        555
      {/if}\
      """

      assert parse!(code) ==
               [
                 {:block, "if",
                  [
                    {:root, {:attribute_expr, "1", %{line: 1, file: "nofile", column: 6}},
                     %{line: 1, file: "nofile", column: 6}}
                  ],
                  [
                    {:block, :default, [], ["\n  111\n"], %{column: 3, file: "nofile", line: 1}},
                    {:block, "elseif",
                     [
                       {:root, {:attribute_expr, "2", %{line: 3, file: "nofile", column: 10}},
                        %{line: 3, file: "nofile", column: 10}}
                     ],
                     [
                       "\n  222\n  ",
                       {:block, "if",
                        [
                          {:root, {:attribute_expr, "3", %{line: 5, file: "nofile", column: 8}},
                           %{line: 5, file: "nofile", column: 8}}
                        ],
                        [
                          {:block, :default, [], ["\n    333\n  "], %{column: 5, file: "nofile", line: 5}},
                          {:block, "else", [], ["\n    444\n  "], %{line: 7, file: "nofile", column: 5}}
                        ], %{has_sub_blocks?: true, line: 5, file: "nofile", column: 5}},
                       "\n"
                     ], %{line: 3, file: "nofile", column: 3}},
                    {:block, "else", [], ["\n  555\n"], %{line: 10, file: "nofile", column: 3}}
                  ], %{has_sub_blocks?: true, line: 1, file: "nofile", column: 3}}
               ]
    end

    test "handle invalid parents for #else" do
      code = """
      <div>
      {#else}
      </div>
      """

      exception = assert_raise ParseError, fn -> parse!(code) end

      message = "no valid parent node defined for {#else}. Possible parents are \"{#if}\" and \"{#for}\""

      assert %ParseError{message: ^message, line: 2} = exception
    end

    test "handle invalid parents for #elseif" do
      code = """
      <div>
      {#elseif}
      </div>
      """

      exception = assert_raise ParseError, fn -> parse!(code) end

      message =
        "no valid parent node defined for {#elseif}. The {#elseif} construct can only be used inside a \"{#if}\""

      assert %ParseError{message: ^message, line: 2} = exception
    end

    test "handle invalid parents for #match" do
      code = """
      <div>
      {#match}
      </div>
      """

      exception = assert_raise ParseError, fn -> parse!(code) end

      message =
        "no valid parent node defined for {#match}. The {#match} construct can only be used inside a \"{#case}\""

      assert %ParseError{message: ^message, line: 2} = exception
    end

    test "raise error on sub-blocks without parent node" do
      code = """
        1
      {#else}
        2
      """

      exception = assert_raise ParseError, fn -> parse!(code) end

      message = "no valid parent node defined for {#else}. Possible parents are \"{#if}\" and \"{#for}\""

      assert %ParseError{message: ^message, line: 2} = exception
    end

    test "raise error on unknown block open" do
      code = """
      {#iff}
        1
      {/if}
      """

      exception = assert_raise ParseError, fn -> parse!(code) end

      message = """
      unknown `{#iff}` block. Available blocks are \
      "if", "unless", "for", "case", "else", "elseif" and "match"\
      """

      assert %ParseError{message: ^message, line: 1} = exception
    end

    test "raise error on unknown block close" do
      code = """
      {#if}
        1
      {/iff}
      """

      exception = assert_raise ParseError, fn -> parse!(code) end

      message = """
      unknown `{/iff}` block. Available blocks are \
      "if", "unless", "for" and "case"\
      """

      assert %ParseError{message: ^message, line: 3} = exception
    end

    test "raise error on blocks without expression" do
      code = """
      1
      {#if}
        2
      {/if}
      """

      message = ~r"nofile:2:\n#{maybe_ansi("error:")} missing expression for block {#if ...}"

      assert_raise Surface.CompileError, message, fn -> parse!(code) end

      code = """
      1
      {#case}
        ...
      {/case}
      """

      message = ~r"nofile:2:\n#{maybe_ansi("error:")} missing expression for block {#case ...}"

      assert_raise Surface.CompileError, message, fn -> parse!(code) end
    end

    test "raise error on missing closing block" do
      code = """
      <br>
      {#if true}
        {#if true}
          1
        {/if}
      """

      exception = assert_raise ParseError, fn -> parse!(code) end

      message = "end of file reached without closing block for {#if}"

      assert %ParseError{message: ^message, line: 2} = exception
    end
  end
end

defmodule Surface.Compiler.ParserSyncTest do
  use ExUnit.Case

  import ExUnit.CaptureIO

  test "warning on unquoted integer values" do
    code = """
    <foo
      prop1=1
    />
    """

    {:warn, line, message} = run_parse(code, __ENV__)

    assert message =~ """
           Using unquoted attribute values is not recommended as they will always be converted to strings.

           For instance, `selected=true` and `tabindex=3` will be translated to `selected="true"` and `tabindex="3"` respectively.

           Hint: if you want to pass a literal boolean or integer, replace `prop1=1` with `prop1={1}`
           """

    assert line == 2
  end

  test "warning on unquoted boolean literals" do
    code = """
    <foo
      prop1=true
      prop2=false
    />
    """

    {:warn, line, message} = run_parse(code, __ENV__)

    assert message =~ """
           Using unquoted attribute values is not recommended as they will always be converted to strings.

           For instance, `selected=true` and `tabindex=3` will be translated to `selected="true"` and `tabindex="3"` respectively.

           Hint: if you want to pass a literal boolean or integer, replace `prop1=true` with `prop1={true}`
           """

    assert message =~ """
           Using unquoted attribute values is not recommended as they will always be converted to strings.

           For instance, `selected=true` and `tabindex=3` will be translated to `selected="true"` and `tabindex="3"` respectively.

           Hint: if you want to pass a literal boolean or integer, replace `prop2=false` with `prop2={false}`
           """

    assert line == 2
  end

  defp run_parse(code, env) do
    env = %{env | line: 1}

    output =
      capture_io(:standard_error, fn ->
        result = Surface.Compiler.Parser.parse!(code, line: 1, caller: env)
        send(self(), {:result, result})
      end)

    result =
      receive do
        {:result, result} -> result
      end

    case output do
      "" ->
        {:ok, result}

      message ->
        {:warn, extract_line(output), message}
    end
  end

  defp extract_line(message) do
    case Regex.run(~r/(?:nofile|.exs):(\d+)/, message) do
      [_, line] ->
        String.to_integer(line)

      _ ->
        :not_found
    end
  end
end
