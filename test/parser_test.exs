defmodule Surface.Compiler.ParserTest do
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
                {"div", [], [], %{line: 2, space: ""}}
              ]}
  end

  test "keep spaces after node" do
    assert parse("<div></div>\n") ==
             {:ok,
              [
                {"div", [], [], %{line: 1, space: ""}},
                "\n"
              ]}
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
                {"div", [], ["\n  Div 1\n"], %{line: 1, space: ""}},
                "\n",
                {"div", [], ["\n  Div 2\n"], %{line: 4, space: ""}},
                "\n"
              ]}
  end

  test "text before and after" do
    assert parse("hello<foo>bar</foo>world") ==
             {:ok, ["hello", {"foo", [], ["bar"], %{line: 1, space: ""}}, "world"]}
  end

  test "component" do
    code = ~S(<MyComponent label="My label"/>)
    {:ok, [node]} = parse(code)

    assert node ==
             {"MyComponent",
              [
                {"label", "My label", %{line: 1, spaces: [" ", "", ""]}}
              ], [], %{line: 1, space: ""}}
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
                 {"span", '', '', %{line: 2, space: ""}},
                 " ",
                 {"span", [], [], %{line: 2, space: ""}},
                 "\n  ",
                 {"span", [], [], %{line: 3, space: ""}},
                 "\n"
               ],
               %{line: 1, space: ""}
             },
             "\n"
           ]
  end

  test "ignore comments" do
    code = """
    <div>
      <!-- This will be ignored -->
      <span/>
    </div>
    """

    assert parse(code) ==
             {:ok,
              [
                {
                  "div",
                  '',
                  [
                    "\n  ",
                    "\n  ",
                    {"span", [], [], %{line: 3, space: ""}},
                    "\n"
                  ],
                  %{line: 1, space: ""}
                },
                "\n"
              ]}
  end

  describe "void elements" do
    test "without attributes" do
      code = """
      <div>
        <hr>
      </div>
      """

      {:ok, [{"div", [], ["\n  ", node, "\n"], _}, "\n"]} = parse(code)
      assert node == {"hr", [], [], %{line: 2, space: ""}}
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
                  {"src", "file.gif", %{line: 3, spaces: ["\n    ", "", ""]}},
                  {"alt", "My image", %{line: 4, spaces: ["\n    ", "", ""]}}
                ], [], %{line: 2, space: "\n  "}}
    end
  end

  describe "HTML only" do
    test "single node" do
      assert parse("<foo>bar</foo>") ==
               {:ok, [{"foo", [], ["bar"], %{line: 1, space: ""}}]}
    end

    test "Elixir node" do
      assert parse("<Foo.Bar>bar</Foo.Bar>") ==
               {:ok, [{"Foo.Bar", [], ["bar"], %{line: 1, space: ""}}]}
    end

    test "mixed nodes" do
      assert parse("<foo>one<bar>two</bar>three</foo>") ==
               {:ok,
                [
                  {"foo", [], ["one", {"bar", [], ["two"], %{line: 1, space: ""}}, "three"],
                   %{line: 1, space: ""}}
                ]}
    end

    test "self-closing nodes" do
      assert parse("<foo>one<bar><bat/></bar>three</foo>") ==
               {:ok,
                [
                  {"foo", [],
                   [
                     "one",
                     {"bar", [], [{"bat", [], [], %{line: 1, space: ""}}], %{line: 1, space: ""}},
                     "three"
                   ], %{line: 1, space: ""}}
                ]}
    end
  end

  describe "interpolation" do
    test "as root" do
      assert parse("{{baz}}") ==
               {:ok, [{:interpolation, "baz", %{line: 1}}]}
    end

    test "without root node but with text" do
      assert parse("foo {{baz}} bar") ==
               {:ok, ["foo ", {:interpolation, "baz", %{line: 1}}, " bar"]}
    end

    test "single curly bracket" do
      assert parse("<foo>{bar}</foo>") ==
               {:ok, [{"foo", [], ["{", "bar}"], %{line: 1, space: ""}}]}
    end

    test "double curly bracket" do
      assert parse("<foo>{{baz}}</foo>") ==
               {:ok, [{"foo", '', [{:interpolation, "baz", %{line: 1}}], %{line: 1, space: ""}}]}
    end

    test "mixed curly bracket" do
      assert parse("<foo>bar{{baz}}bat</foo>") ==
               {:ok,
                [
                  {"foo", '', ["bar", {:interpolation, "baz", %{line: 1}}, "bat"],
                   %{line: 1, space: ""}}
                ]}
    end

    test "single-closing curly bracket" do
      assert parse("<foo>bar{{ 'a}b' }}bat</foo>") ==
               {:ok,
                [
                  {"foo", [], ["bar", {:interpolation, " 'a}b' ", %{line: 1}}, "bat"],
                   %{line: 1, space: ""}}
                ]}
    end
  end

  describe "with macros" do
    test "single node" do
      assert parse("<#foo>bar</#foo>") ==
               {:ok, [{"#foo", [], ["bar"], %{line: 1, space: ""}}]}
    end

    test "mixed nodes" do
      assert parse("<#foo>one<bar>two</baz>three</#foo>") ==
               {:ok, [{"#foo", [], ["one<bar>two</baz>three"], %{line: 1, space: ""}}]}

      assert parse("<#foo>one<#bar>two</#baz>three</#foo>") ==
               {:ok, [{"#foo", [], ["one<#bar>two</#baz>three"], %{line: 1, space: ""}}]}

      assert parse("<#foo>one<bar>two<baz>three</#foo>") ==
               {:ok, [{"#foo", [], ["one<bar>two<baz>three"], %{line: 1, space: ""}}]}

      assert parse("<#foo>one</bar>two</baz>three</#foo>") ==
               {:ok, [{"#foo", [], ["one</bar>two</baz>three"], %{line: 1, space: ""}}]}
    end

    test "macro issue" do
      assert parse("<#Macro/>") ==
               {:ok, [{"#Macro", '', [], %{line: 1, space: ""}}]}
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
      assert parse("<#Foo>one {{ @var }} two</#Foo>") ==
               {:ok, [{"#Foo", [], ["one {{ @var }} two"], %{line: 1, space: ""}}]}
    end
  end

  describe "errors on" do
    test "invalid opening tag" do
      assert parse("<>bar</>") ==
               {:error, "expected opening HTML tag", 1}
    end

    test "invalid closing tag" do
      assert parse("<foo>bar</></foo>") ==
               {:error, "expected closing tag for \"foo\"", 1}
    end

    test "tag mismatch" do
      assert parse("<foo>bar</baz>") ==
               {:error, "closing tag \"baz\" did not match opening tag \"foo\"", 1}
    end

    test "incomplete tag content" do
      assert parse("<foo>bar") ==
               {:error, "expected closing tag for \"foo\"", 1}
    end

    test "incomplete macro content" do
      assert parse("<#foo>bar</#bar>") ==
               {:error, "expected closing tag for \"#foo\"", 1}
    end

    test "non-closing interpolation" do
      assert parse("<foo>{{bar</foo>") ==
               {:error, "expected closing for interpolation", 1}
    end
  end

  describe "attributes" do
    test "regular nodes" do
      code = """
      <foo
        prop1="value1"
        prop2="value2"
      >
        bar
        <div>{{ var }}</div>
      </foo>
      """

      attributes = [
        {"prop1", "value1", %{line: 2, spaces: ["\n  ", "", ""]}},
        {"prop2", "value2", %{line: 3, spaces: ["\n  ", "", ""]}}
      ]

      children = [
        "\n  bar\n  ",
        {"div", [], [{:interpolation, " var ", %{line: 6}}], %{line: 6, space: ""}},
        "\n"
      ]

      assert parse(code) == {:ok, [{"foo", attributes, children, %{line: 1, space: "\n"}}, "\n"]}
    end

    test "self-closing nodes" do
      code = """
      <foo
        prop1="value1"
        prop2="value2"
      />
      """

      attributes = [
        {"prop1", "value1", %{line: 2, spaces: ["\n  ", "", ""]}},
        {"prop2", "value2", %{line: 3, spaces: ["\n  ", "", ""]}}
      ]

      assert parse(code) == {:ok, [{"foo", attributes, [], %{line: 1, space: "\n"}}, "\n"]}
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
        {"prop1", "value1", %{line: 2, spaces: ["\n  ", "", ""]}},
        {"prop2", "value2", %{line: 3, spaces: ["\n  ", "", ""]}}
      ]

      assert parse(code) ==
               {:ok, [{"#foo", attributes, ["\n  bar\n"], %{line: 1, space: "\n"}}, "\n"]}
    end

    test "regular nodes with whitespaces" do
      code = """
      <foo
        prop1
        prop2 = "value 2"
        prop3 =
          {{ var3 }}
        prop4
      ></foo>
      """

      attributes = [
        {"prop1", true, %{line: 2, spaces: ["\n  ", "\n  "]}},
        {"prop2", "value 2", %{line: 3, spaces: ["", " ", " "]}},
        {"prop3", {:attribute_expr, " var3 ", %{line: 5}},
         %{line: 4, spaces: ["\n  ", " ", "\n    "]}},
        {"prop4", true, %{line: 6, spaces: ["\n  ", "\n"]}}
      ]

      assert parse(code) == {:ok, [{"foo", attributes, [], %{line: 1, space: ""}}, "\n"]}
    end

    test "self-closing nodes with whitespaces" do
      code = """
      <foo
        prop1
        prop2 = "2"
        prop3 =
          {{ var3 }}
        prop4
      />
      """

      attributes = [
        {"prop1", true, %{line: 2, spaces: ["\n  ", "\n  "]}},
        {"prop2", "2", %{line: 3, spaces: ["", " ", " "]}},
        {"prop3", {:attribute_expr, " var3 ", %{line: 5}},
         %{line: 4, spaces: ["\n  ", " ", "\n    "]}},
        {"prop4", true, %{line: 6, spaces: ["\n  ", "\n"]}}
      ]

      assert parse(code) == {:ok, [{"foo", attributes, [], %{line: 1, space: ""}}, "\n"]}
    end

    test "value as expression" do
      code = """
      <foo
        prop1={{ var1 }}
        prop2={{ var2 }}
      />
      """

      attributes = [
        {"prop1", {:attribute_expr, " var1 ", %{line: 2}},
         %{line: 2, spaces: ["\n  ", "", ""]}},
        {"prop2", {:attribute_expr, " var2 ", %{line: 3}}, %{line: 3, spaces: ["\n  ", "", ""]}}
      ]

      assert parse(code) == {:ok, [{"foo", attributes, [], %{line: 1, space: "\n"}}, "\n"]}
    end

    test "integer values" do
      code = """
      <foo
        prop1=1
        prop2=2
      />
      """

      attributes = [
        {"prop1", 1, %{line: 2, spaces: ["\n  ", "", ""]}},
        {"prop2", 2, %{line: 3, spaces: ["\n  ", "", ""]}}
      ]

      assert parse(code) == {:ok, [{"foo", attributes, [], %{line: 1, space: "\n"}}, "\n"]}
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
        {"prop1", true, %{line: 2, spaces: ["\n  ", "\n  "]}},
        {"prop2", true, %{line: 3, spaces: ["", "", ""]}},
        {"prop3", false, %{line: 4, spaces: ["\n  ", "", ""]}},
        {"prop4", true, %{line: 5, spaces: ["\n  ", "\n"]}}
      ]

      assert parse(code) == {:ok, [{"foo", attributes, [], %{line: 1, space: ""}}, "\n"]}
    end

    test "string with embedded interpolation" do
      code = """
      <foo prop="before {{ var }} after"/>
      """

      attr_value = ["before ", {:attribute_expr, " var ", %{line: 1}}, " after"]

      attributes = [
        {"prop", attr_value, %{line: 1, spaces: [" ", "", ""]}}
      ]

      assert parse(code) == {:ok, [{"foo", attributes, [], %{line: 1, space: ""}}, "\n"]}
    end

    test "string with only an embedded interpolation" do
      code = """
      <foo prop="{{ var }}"/>
      """

      attr_value = [{:attribute_expr, " var ", %{line: 1}}]

      attributes = [
        {"prop", attr_value, %{line: 1, spaces: [" ", "", ""]}}
      ]

      assert parse(code) == {:ok, [{"foo", attributes, [], %{line: 1, space: ""}}, "\n"]}
    end
  end
end
