defmodule Surface.Compiler.CSSTokenizerTest do
  use ExUnit.Case, async: true

  alias Surface.Compiler.CSSTokenizer

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
end
