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
               {:selector, [text: ".root", ws: " "]},
               {:block, "{",
                [
                  {:ws, " "},
                  {:declaration, [{:text, "padding:"}, {:ws, " "}, {:text, "1px"}]},
                  :semicolon,
                  {:ws, " "}
                ], %{column: 7, column_end: 23, line: 1, line_end: 1}}
             ]
  end

  test "parse selector with a single declaration without spaces nor semicolon" do
    css = ".root{padding: 1px}"

    assert CSSParser.parse!(css) == [
             {:selector, [{:text, ".root"}]},
             {:block, "{", [{:declaration, [{:text, "padding:"}, {:ws, " "}, {:text, "1px"}]}],
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
             {:selector, [text: ".root", ws: " "]},
             {:block, "{",
              [
                {:ws, "\n  "},
                {:declaration, [text: "padding:", ws: " ", text: "1px"]},
                :semicolon,
                {:ws, "\n  "},
                {:declaration, [text: "margin:", ws: " ", text: "1px"]},
                :semicolon,
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
                {:block, "(", [{:text, "min-width:"}, {:ws, " "}, {:text, "1216px"}],
                 %{column: 19, column_end: 37, line: 1, line_end: 1}},
                {:ws, " "}
              ]},
             {:block, "{",
              [
                {:ws, "\n  "},
                {:selector, [{:text, ".a"}, {:ws, " "}]},
                {:block, "{",
                 [
                   {:declaration, [{:text, "display:"}, {:ws, " "}, {:text, "block"}]}
                 ], %{column: 6, column_end: 21, line: 2, line_end: 2}},
                {:ws, "\n"}
              ], %{column: 39, column_end: 1, line: 1, line_end: 3}}
           ]
  end

  test "parse element with class selector" do
    css = """
    div.blog { display: block }
    """

    assert [{:selector, [text: "div.blog", ws: " "]} | _] = CSSParser.parse!(css)
  end

  test "parse multiple css rules" do
    css = """
    /* padding: s-bind(padding); */

    .root {
      --custom-color: s-bind('@css.background');
    }

    .a:has(> img) > b[class="btn"], c {
      padding: s-bind('@padding');
    }

    @media screen and (min-width: 1216px) {
      .blog { display: block; }
    }

    @tailwind utilities;
    """

    assert CSSParser.parse!(css) == [
             {:comment, " padding: s-bind(padding); "},
             {:ws, "\n\n"},
             {:selector, [text: ".root", ws: " "]},
             {:block, "{",
              [
                {:ws, "\n  "},
                {:declaration,
                 [
                   {:text, "--custom-color:"},
                   {:ws, " "},
                   {:text, "s-bind"},
                   {:block, "(", [{:string, "\'", "@css.background"}],
                    %{column: 25, column_end: 43, line: 4, line_end: 4}}
                 ]},
                :semicolon,
                {:ws, "\n"}
              ], %{column: 7, column_end: 1, line: 3, line_end: 5}},
             {:ws, "\n\n"},
             {:selector,
              [
                {:text, ".a:has"},
                {:block, "(", [text: ">", ws: " ", text: "img"],
                 %{column: 7, column_end: 13, line: 7, line_end: 7}},
                {:ws, " "},
                {:text, ">"},
                {:ws, " "},
                {:text, "b"},
                {:block, "[", [{:text, "class="}, {:string, "\"", "btn"}],
                 %{column: 18, column_end: 30, line: 7, line_end: 7}}
              ]},
             :comma,
             {:ws, " "},
             {:selector, [text: "c", ws: " "]},
             {:block, "{",
              [
                {:ws, "\n  "},
                {:declaration,
                 [
                   {:text, "padding:"},
                   {:ws, " "},
                   {:text, "s-bind"},
                   {:block, "(", [{:string, "'", "@padding"}], %{column: 18, column_end: 29, line: 8, line_end: 8}}
                 ]},
                :semicolon,
                {:ws, "\n"}
              ], %{column: 35, column_end: 1, line: 7, line_end: 9}},
             {:ws, "\n\n"},
             {:at_rule,
              [
                {:text, "@media"},
                {:ws, " "},
                {:text, "screen"},
                {:ws, " "},
                {:text, "and"},
                {:ws, " "},
                {:block, "(", [text: "min-width:", ws: " ", text: "1216px"],
                 %{column: 19, column_end: 37, line: 11, line_end: 11}},
                {:ws, " "}
              ]},
             {:block, "{",
              [
                {:ws, "\n  "},
                {:selector, [text: ".blog", ws: " "]},
                {:block, "{",
                 [
                   {:ws, " "},
                   {:declaration, [text: "display:", ws: " ", text: "block"]},
                   :semicolon,
                   {:ws, " "}
                 ], %{column: 9, column_end: 27, line: 12, line_end: 12}},
                {:ws, "\n"}
              ], %{column: 39, column_end: 1, line: 11, line_end: 13}},
             {:ws, "\n\n"},
             {:at_rule, [text: "@tailwind", ws: " ", text: "utilities"]},
             :semicolon,
             {:ws, "\n"}
           ]
  end
end
