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
                ]}
             ]
  end

  test "parse selector with a single declaration without spaces nor semicolon" do
    css = ".root{padding: 1px}"

    assert CSSParser.parse!(css) == [
             {:selector, [{:text, ".root"}]},
             {:block, "{", [{:declaration, [{:text, "padding:"}, {:ws, " "}, {:text, "1px"}]}]}
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
              ]}
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
                {:block, "(", [{:text, "min-width:"}, {:ws, " "}, {:text, "1216px"}]},
                {:ws, " "}
              ]},
             {:block, "{",
              [
                {:ws, "\n  "},
                {:selector, [{:text, ".a"}, {:ws, " "}]},
                {:block, "{",
                 [
                   {:declaration, [{:text, "display:"}, {:ws, " "}, {:text, "block"}]}
                 ]},
                {:ws, "\n"}
              ]}
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
                   {:block, "(", [{:string, "\'", "@css.background"}]}
                 ]},
                :semicolon,
                {:ws, "\n"}
              ]},
             {:ws, "\n\n"},
             {:selector,
              [
                {:text, ".a:has"},
                {:block, "(", [text: ">", ws: " ", text: "img"]},
                {:ws, " "},
                {:text, ">"},
                {:ws, " "},
                {:text, "b"},
                {:block, "[", [{:text, "class="}, {:string, "\"", "btn"}]}
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
                   {:block, "(", [{:string, "'", "@padding"}]}
                 ]},
                :semicolon,
                {:ws, "\n"}
              ]},
             {:ws, "\n\n"},
             {:at_rule,
              [
                {:text, "@media"},
                {:ws, " "},
                {:text, "screen"},
                {:ws, " "},
                {:text, "and"},
                {:ws, " "},
                {:block, "(", [text: "min-width:", ws: " ", text: "1216px"]},
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
                 ]},
                {:ws, "\n"}
              ]},
             {:ws, "\n\n"},
             {:at_rule, [text: "@tailwind", ws: " ", text: "utilities"]},
             :semicolon,
             {:ws, "\n"}
           ]
  end
end
