defmodule Surface.Compiler.CSSTokenizerTest do
  use ExUnit.Case, async: true

  alias Surface.Compiler.CSSTokenizer
  alias Surface.Compiler.CSSParserError

  test "tokenize!" do
    css = """
    /* padding: s-bind(padding); */

    .root {
      --custom-color: s-bind('@css.background');
    }

    .a > b[class="btn"], c {
      padding: s-bind('@padding');
    }

    @media screen and (min-width: 1216px) {
      .blog { display: block; }
    }

    @tailwind utilities;
    """

    assert CSSTokenizer.tokenize!(css) == [
             {:comment, " padding: s-bind(padding); "},
             {:ws, "\n\n"},
             {:text, ".root"},
             {:ws, " "},
             {:block_open, "{"},
             {:ws, "\n  "},
             {:text, "--custom-color:"},
             {:ws, " "},
             {:text, "s-bind"},
             {:block_open, "("},
             {:string, "\'", "@css.background"},
             {:block_close, ")"},
             :semicolon,
             {:ws, "\n"},
             {:block_close, "}"},
             {:ws, "\n\n"},
             {:text, ".a"},
             {:ws, " "},
             {:text, ">"},
             {:ws, " "},
             {:text, "b"},
             {:block_open, "["},
             {:text, "class="},
             {:string, "\"", "btn"},
             {:block_close, "]"},
             :comma,
             {:ws, " "},
             {:text, "c"},
             {:ws, " "},
             {:block_open, "{"},
             {:ws, "\n  "},
             {:text, "padding:"},
             {:ws, " "},
             {:text, "s-bind"},
             {:block_open, "("},
             {:string, "'", "@padding"},
             {:block_close, ")"},
             :semicolon,
             {:ws, "\n"},
             {:block_close, "}"},
             {:ws, "\n\n"},
             {:text, "@media"},
             {:ws, " "},
             {:text, "screen"},
             {:ws, " "},
             {:text, "and"},
             {:ws, " "},
             {:block_open, "("},
             {:text, "min-width:"},
             {:ws, " "},
             {:text, "1216px"},
             {:block_close, ")"},
             {:ws, " "},
             {:block_open, "{"},
             {:ws, "\n  "},
             {:text, ".blog"},
             {:ws, " "},
             {:block_open, "{"},
             {:ws, " "},
             {:text, "display:"},
             {:ws, " "},
             {:text, "block"},
             :semicolon,
             {:ws, " "},
             {:block_close, "}"},
             {:ws, "\n"},
             {:block_close, "}"},
             {:ws, "\n\n"},
             {:text, "@tailwind"},
             {:ws, " "},
             {:text, "utilities"},
             :semicolon,
             {:ws, "\n"}
           ]
  end

  test "handle double quoted string containing single quote" do
    css = """
    .a[title="I'm here"]{padding: 1px}
    """

    assert [_, _, {:text, "title="}, {:string, "\"", "I'm here"}, _ | _] = CSSTokenizer.tokenize!(css)
  end

  test "handle single quoted string containing double quote" do
    css = """
    .a[title='quote:"']{padding: 1px}
    """

    assert [_, _, {:text, "title="}, {:string, "\'", "quote:\""}, _ | _] = CSSTokenizer.tokenize!(css)
  end

  test "raise error on missing closing `}`" do
    css = """
    .a {
      display: none;
    """

    %CSSParserError{message: message, line: line, column: column} =
      assert_raise CSSParserError, fn -> CSSTokenizer.tokenize!(css) end

    assert message == "missing closing `}` for token `{` defined at line 1, column 4"

    assert line == 3
    assert column == 1
  end

  test "raise error on missing closing `)`" do
    css = """
    .a {
      padding: s-bind('@padding'
    """

    %CSSParserError{message: message, line: line, column: column} =
      assert_raise CSSParserError, fn -> CSSTokenizer.tokenize!(css) end

    assert message == "missing closing `)` for token `(` defined at line 2, column 18"

    assert line == 3
    assert column == 1
  end

  test "raise error on missing closing `]`" do
    css = """
    .a { padding: 1px; }
    .b[title="test"
    """

    %CSSParserError{message: message, line: line, column: column} =
      assert_raise CSSParserError, fn -> CSSTokenizer.tokenize!(css) end

    assert message == "missing closing `]` for token `[` defined at line 2, column 3"

    assert line == 3
    assert column == 1
  end

  test "raise error on missing closing `*/`" do
    css = """
    .a { display: none; }

    class /* a

    .b { display: none; }
    """

    %CSSParserError{message: message, line: line, column: column} =
      assert_raise CSSParserError, fn -> CSSTokenizer.tokenize!(css) end

    assert message == "missing closing `*/` for token `/*` defined at line 3, column 7"
    assert line == 6
    assert column == 1
  end

  test "raise error on missing closing `\"`" do
    css = """
    .a[title="quote
    """

    %CSSParserError{message: message, line: line, column: column} =
      assert_raise CSSParserError, fn -> CSSTokenizer.tokenize!(css) end

    assert message == ~S(missing closing `"` for token `"` defined at line 1, column 10)
    assert line == 2
    assert column == 1
  end

  test "raise error on missing closing `'`" do
    css = """
    .a[title='quote
    """

    %CSSParserError{message: message, line: line, column: column} =
      assert_raise CSSParserError, fn -> CSSTokenizer.tokenize!(css) end

    assert message == "missing closing `'` for token `'` defined at line 1, column 10"
    assert line == 2
    assert column == 1
  end

  test "raise error on unexpected token `*/`" do
    css = """
    .a { display: none; }

    .b */
    """

    %CSSParserError{message: message, line: line, column: column} =
      assert_raise CSSParserError, fn -> CSSTokenizer.tokenize!(css) end

    assert message == "unexpected token `*/`"
    assert line == 3
    assert column == 4
  end

  test "raise error on unexpected token `}`" do
    css = """
    .a { display: none; }
    .b  display: none; }
    """

    %CSSParserError{message: message, line: line, column: column} =
      assert_raise CSSParserError, fn -> CSSTokenizer.tokenize!(css) end

    assert message == "unexpected token `}`"
    assert line == 2
    assert column == 20
  end

  test "raise error on unexpected token `)`" do
    css = """
    .a {
      padding: v-bind '@padding');
    }
    """

    %CSSParserError{message: message, line: line, column: column} =
      assert_raise CSSParserError, fn -> CSSTokenizer.tokenize!(css) end

    assert message == "unexpected token `)`"
    assert line == 2
    assert column == 29
  end

  test "raise error on unexpected token `]`" do
    css = """
    .a {
      padding]: 1px;;
    }
    """

    %CSSParserError{message: message, line: line, column: column} =
      assert_raise CSSParserError, fn -> CSSTokenizer.tokenize!(css) end

    assert message == "unexpected token `]`"
    assert line == 2
    assert column == 10
  end
end
