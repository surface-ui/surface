defmodule Surface.Compiler.CSSParserTest do
  use ExUnit.Case, async: true

  alias Surface.Compiler.CSSParser

  test "parse comment" do
    css = "/* padding: s-bind(padding); */"
    assert CSSParser.parse!(css) == [{:comment, " padding: s-bind(padding); "}]
  end

  test "parse selector with a single declaration" do
    css = ".root { padding: 1px; }"

    assert CSSParser.parse!(css) ==
             [
               {:selector_list, [[text: ".root", ws: " "]]},
               {:block, "{",
                [
                  {:ws, " "},
                  {:declaration, [{:text, "padding"}, {:text, ":"}, {:ws, " "}, {:text, "1px"}, :semicolon]},
                  {:ws, " "}
                ], %{column: 7, column_end: 23, line: 1, line_end: 1}}
             ]
  end

  test "parse selector with a single declaration without spaces nor semicolon" do
    css = ".root{padding: 1px}"

    assert CSSParser.parse!(css) == [
             {:selector_list, [[{:text, ".root"}]]},
             {:block, "{", [{:declaration, [{:text, "padding"}, {:text, ":"}, {:ws, " "}, {:text, "1px"}]}],
              %{column: 6, column_end: 19, line: 1, line_end: 1}}
           ]
  end

  test "parse selector with multiple declarations" do
    css = """
    .root {
      padding: 1px;
      margin: 1px;
    }\
    """

    assert CSSParser.parse!(css) == [
             {:selector_list, [[text: ".root", ws: " "]]},
             {:block, "{",
              [
                {:ws, "\n  "},
                {:declaration, [{:text, "padding"}, {:text, ":"}, {:ws, " "}, {:text, "1px"}, :semicolon]},
                {:ws, "\n  "},
                {:declaration, [{:text, "margin"}, {:text, ":"}, {:ws, " "}, {:text, "1px"}, :semicolon]},
                {:ws, "\n"}
              ], %{column: 7, column_end: 1, line: 1, line_end: 4}}
           ]
  end

  test "parse at-rule" do
    css = """
    @media screen and (min-width: 1216px) {
      .a {display: block}
    }\
    """

    assert CSSParser.parse!(css) == [
             {:at_rule,
              [
                {:text, "@media"},
                {:ws, " "},
                {:text, "screen"},
                {:ws, " "},
                {:text, "and"},
                {:ws, " "},
                {:block, "(", [{:text, "min-width"}, {:text, ":"}, {:ws, " "}, {:text, "1216px"}],
                 %{column: 19, column_end: 37, line: 1, line_end: 1}},
                {:ws, " "}
              ]},
             {:block, "{",
              [
                {:ws, "\n  "},
                {:selector_list, [[{:text, ".a"}, {:ws, " "}]]},
                {:block, "{",
                 [
                   {:declaration, [{:text, "display"}, {:text, ":"}, {:ws, " "}, {:text, "block"}]}
                 ], %{column: 6, column_end: 21, line: 2, line_end: 2}},
                {:ws, "\n"}
              ], %{column: 39, column_end: 1, line: 1, line_end: 3}}
           ]
  end

  test "parse element with class selector" do
    css = """
    div.blog { display: block }
    """

    assert [{:selector_list, [[{:text, "div"}, {:text, ".blog"}, {:ws, " "}]]} | _] = CSSParser.parse!(css)
  end

  test "parse multiple selector blocks" do
    css = """
    .a{padding: 1px}
    .b{padding: 1px}
    """

    assert [
             {:selector_list, [[text: ".a"]]},
             {:block, "{", [declaration: [text: "padding", text: ":", ws: " ", text: "1px"]], _},
             {:ws, "\n"},
             {:selector_list, [[text: ".b"]]},
             {:block, "{", [declaration: [text: "padding", text: ":", ws: " ", text: "1px"]], _},
             {:ws, "\n"}
           ] = CSSParser.parse!(css)
  end

  test "parse multiple selector items" do
    css = ".a > .b, .c ,  .d {padding: 1px}"

    assert CSSParser.parse!(css) == [
             {:selector_list,
              [
                [
                  {:text, ".a"},
                  {:ws, " "},
                  {:text, ">"},
                  {:ws, " "},
                  {:text, ".b"},
                  {:comma, nil},
                  {:ws, " "}
                ],
                [
                  {:text, ".c"},
                  {:ws, " "},
                  {:comma, nil},
                  {:ws, "  "}
                ],
                [
                  {:text, ".d"},
                  {:ws, " "}
                ]
              ]},
             {:block, "{",
              [
                {:declaration, [{:text, "padding"}, {:text, ":"}, {:ws, " "}, {:text, "1px"}]}
              ], %{column: 19, column_end: 32, line: 1, line_end: 1}}
           ]
  end
end
