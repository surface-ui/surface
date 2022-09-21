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
      .blog { display: block; margin: min(100px, 200px); }
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
             {:text, "--custom-color"},
             {:text, ":"},
             {:ws, " "},
             {:text, "s-bind"},
             {:block_open, "("},
             {:string, "\'", "@css.background"},
             {:block_close, ")", %{column: 43, line: 4, opening_column: 25, opening_line: 4}},
             :semicolon,
             {:ws, "\n"},
             {:block_close, "}", %{column: 1, line: 5, opening_column: 7, opening_line: 3}},
             {:ws, "\n\n"},
             {:text, ".a"},
             {:ws, " "},
             {:text, ">"},
             {:ws, " "},
             {:text, "b"},
             {:block_open, "["},
             {:text, "class="},
             {:string, "\"", "btn"},
             {:block_close, "]", %{column: 19, line: 7, opening_column: 7, opening_line: 7}},
             {:comma, nil},
             {:ws, " "},
             {:text, "c"},
             {:ws, " "},
             {:block_open, "{"},
             {:ws, "\n  "},
             {:text, "padding"},
             {:text, ":"},
             {:ws, " "},
             {:text, "s-bind"},
             {:block_open, "("},
             {:string, "'", "@padding"},
             {:block_close, ")", %{column: 29, line: 8, opening_column: 18, opening_line: 8}},
             :semicolon,
             {:ws, "\n"},
             {:block_close, "}", %{column: 1, line: 9, opening_column: 24, opening_line: 7}},
             {:ws, "\n\n"},
             {:text, "@media"},
             {:ws, " "},
             {:text, "screen"},
             {:ws, " "},
             {:text, "and"},
             {:ws, " "},
             {:block_open, "("},
             {:text, "min-width"},
             {:text, ":"},
             {:ws, " "},
             {:text, "1216px"},
             {:block_close, ")", %{column: 37, line: 11, opening_column: 19, opening_line: 11}},
             {:ws, " "},
             {:block_open, "{"},
             {:ws, "\n  "},
             {:text, ".blog"},
             {:ws, " "},
             {:block_open, "{"},
             {:ws, " "},
             {:text, "display"},
             {:text, ":"},
             {:ws, " "},
             {:text, "block"},
             :semicolon,
             {:ws, " "},
             {:text, "margin"},
             {:text, ":"},
             {:ws, " "},
             {:text, "min"},
             {:block_open, "("},
             {:text, "100px"},
             {:comma, "("},
             {:ws, " "},
             {:text, "200px"},
             {:block_close, ")", %{column: 51, line: 12, opening_column: 38, opening_line: 12}},
             :semicolon,
             {:ws, " "},
             {:block_close, "}", %{column: 54, line: 12, opening_column: 9, opening_line: 12}},
             {:ws, "\n"},
             {:block_close, "}", %{column: 1, line: 13, opening_column: 39, opening_line: 11}},
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

  test "handle empty strings" do
    css = "div{content:''}"

    assert [
             {:text, "div"},
             {:block_open, "{"},
             {:text, "content"},
             {:text, ":"},
             {:string, "'", ""},
             {:block_close, "}", _}
           ] = CSSTokenizer.tokenize!(css)

    css = ~S(div{content:""})

    assert [
             {:text, "div"},
             {:block_open, "{"},
             {:text, "content"},
             {:text, ":"},
             {:string, "\"", ""},
             {:block_close, "}", _}
           ] = CSSTokenizer.tokenize!(css)
  end

  test "handle empty {} blocks" do
    css = "div{}"

    assert [
             {:text, "div"},
             {:block_open, "{"},
             {:block_close, "}", _}
           ] = CSSTokenizer.tokenize!(css)
  end

  test "handle empty () blocks" do
    css = "div{foo()}"

    assert [
             {:text, "div"},
             {:block_open, "{"},
             {:text, "foo"},
             {:block_open, "("},
             {:block_close, ")", _},
             {:block_close, "}", _}
           ] = CSSTokenizer.tokenize!(css)
  end

  test "handle pseudo classes" do
    css = """
    .a:has(>img) {padding: 1px}
    """

    assert CSSTokenizer.tokenize!(css) == [
             {:text, ".a"},
             {:text, ":has"},
             {:block_open, "("},
             {:text, ">"},
             {:text, "img"},
             {:block_close, ")", %{column: 12, line: 1, opening_column: 7, opening_line: 1}},
             {:ws, " "},
             {:block_open, "{"},
             {:text, "padding"},
             {:text, ":"},
             {:ws, " "},
             {:text, "1px"},
             {:block_close, "}", %{column: 27, line: 1, opening_column: 14, opening_line: 1}},
             {:ws, "\n"}
           ]
  end

  test "handle multiple selectors" do
    css = """
    div.a:first-child.b {padding: 1px}
    """

    assert CSSTokenizer.tokenize!(css) == [
             {:text, "div"},
             {:text, ".a"},
             {:text, ":first-child"},
             {:text, ".b"},
             {:ws, " "},
             {:block_open, "{"},
             {:text, "padding"},
             {:text, ":"},
             {:ws, " "},
             {:text, "1px"},
             {:block_close, "}", %{column: 34, line: 1, opening_column: 21, opening_line: 1}},
             {:ws, "\n"}
           ]
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
