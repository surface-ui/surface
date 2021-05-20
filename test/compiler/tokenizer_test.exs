defmodule Surface.Compiler.TokenizerTest do
  use ExUnit.Case, async: true

  import Surface.Compiler.Tokenizer
  alias Surface.Compiler.ParseError

  describe "text" do
    test "represented as {:text, value}" do
      assert tokenize!("Hello") == [{:text, "Hello"}]
    end

    test "with multiple lines" do
      tokens =
        tokenize!("""
        first
        second
        third
        """)

      assert tokens == [{:text, "first\nsecond\nthird\n"}]
    end

    test "keep line breaks unchanged" do
      assert tokenize!("first\nsecond\r\nthird") == [{:text, "first\nsecond\r\nthird"}]
    end
  end

  describe "comment" do
    test "represented as {:comment, comment}" do
      assert tokenize!("Begin<!-- comment -->End") ==
               [{:text, "Begin"}, {:comment, "<!-- comment -->"}, {:text, "End"}]
    end

    test "multiple lines and wrapped by tags" do
      code = """
      <p>
      <!--
      <div>
      -->
      </p><br>\
      """

      assert [
               {:tag_open, "p", [], %{line: 1, column: 2}},
               {:text, "\n"},
               {:comment, "<!--\n<div>\n-->"},
               {:text, "\n"},
               {:tag_close, "p", %{line: 5, column: 3}},
               {:tag_open, "br", [], %{line: 5, column: 6}}
             ] = tokenize!(code)
    end

    test "raise on incomplete comment (EOF)" do
      assert_raise ParseError, "nofile:3:7: expected closing `-->` for comment", fn ->
        tokenize!("""
        <div>
        <!-- a comment)
        </div>\
        """)
      end
    end
  end

  describe "EEx interpolation" do
    test "raises when present" do
      assert_raise ParseError,
                   "nofile:2:5: EEx syntax `<%=` not allowed. Please use the Surface interpolation syntax `{{ foo = :bar }}`",
                   fn ->
                     tokenize!("""
                     <div>
                     <%= foo = :bar %>
                     </div>
                     """)
                   end
    end
  end

  describe "interpolation in body" do
    test "represented as {:interpolation, value, meta}" do
      assert tokenize!("""
             before
             ={1} after\
             """) == [
               {:text, "before\n="},
               {:interpolation, "1",
                %{column: 3, line: 2, column_end: 4, line_end: 2, file: "nofile"}},
               {:text, " after"}
             ]
    end

    test "value containing curly braces" do
      tokens = tokenize!("before{func({1, 3})}after")

      assert tokens == [
               {:text, "before"},
               {:interpolation, "func({1, 3})",
                %{column: 8, line: 1, column_end: 20, line_end: 1, file: "nofile"}},
               {:text, "after"}
             ]
    end
  end

  describe "opening tag" do
    test "represented as {:tag_open, name, attrs, meta}" do
      tokens = tokenize!("<div>")
      assert [{:tag_open, "div", [], %{}}] = tokens
    end

    test "with space after name" do
      tokens = tokenize!("<div >")
      assert [{:tag_open, "div", [], %{}}] = tokens
    end

    test "with line break after name" do
      tokens = tokenize!("<div\n>")
      assert [{:tag_open, "div", [], %{}}] = tokens
    end

    test "self close" do
      tokens = tokenize!("<div/>")
      assert [{:tag_open, "div", [], %{self_close: true}}] = tokens
    end

    test "compute line and column" do
      tokens =
        tokenize!("""
        <div>
          <span>

        <p>\
        """)

      assert [
               {:tag_open, "div", [], %{line: 1, column: 2}},
               {:text, _},
               {:tag_open, "span", [], %{line: 2, column: 4}},
               {:text, _},
               {:tag_open, "p", [], %{line: 4, column: 2}}
             ] = tokens
    end

    test "compute line and column with multiple tags on the same line" do
      tokens =
        tokenize!("""
        <div>
          <span/> <span/>

        <p>\
        """)

      assert [
               {:tag_open, "div", [], %{line: 1, column: 2}},
               {:text, _},
               {:tag_open, "span", [], %{line: 2, column: 4}},
               {:text, _},
               {:tag_open, "span", [], %{line: 2, column: 12}},
               {:text, _},
               {:tag_open, "p", [], %{line: 4, column: 2}}
             ] = tokens
    end

    test "raise on missing tag name" do
      assert_raise ParseError, "nofile:2:4: expected tag name", fn ->
        tokenize!("""
        <div>
          <>\
        """)
      end

      assert_raise ParseError, "nofile:2:5: expected tag name", fn ->
        tokenize!("""
        <div>
          </>\
        """)
      end
    end
  end

  describe "attributes" do
    test "represented as a list of {name, tuple | nil}, where tuple is the {type, value}" do
      attrs = tokenize_attrs(~S(<div class="panel" style={@style} hidden selected=true>))

      assert [
               {"class", {:string, "panel", %{}}, %{}},
               {"style", {:expr, "@style", %{}}, %{}},
               {"hidden", nil, %{}},
               {"selected", {:string, "true", %{}}, %{}}
             ] = attrs
    end

    test "compute line and column" do
      attrs =
        tokenize_attrs("""
        <div
          class="panel"
          style={@style} hidden>\
        """)

      assert [
               {"class", {:string, "panel", %{}},
                %{line: 2, column: 3, line_end: 2, column_end: 8}},
               {"style", {:expr, "@style", %{}},
                %{line: 3, column: 3, line_end: 3, column_end: 8}},
               {"hidden", nil, %{line: 3, column: 18, line_end: 3, column_end: 24}}
             ] = attrs
    end

    test "accepts space between the name and `=`" do
      attrs = tokenize_attrs(~S(<div class ="panel">))

      assert [{"class", {:string, "panel", %{}}, %{}}] = attrs
    end

    test "accepts line breaks between the name and `=`" do
      attrs = tokenize_attrs("<div class\n=\"panel\">")

      assert [{"class", {:string, "panel", %{}}, %{}}] = attrs

      attrs = tokenize_attrs("<div class\r\n=\"panel\">")

      assert [{"class", {:string, "panel", %{}}, %{}}] = attrs
    end

    test "accepts space between `=` and the value" do
      attrs = tokenize_attrs(~S(<div class= "panel">))

      assert [{"class", {:string, "panel", %{}}, %{}}] = attrs
    end

    test "accepts line breaks between `=` and the value" do
      attrs = tokenize_attrs("<div class=\n\"panel\">")

      assert [{"class", {:string, "panel", %{}}, %{}}] = attrs

      attrs = tokenize_attrs("<div class=\r\n\"panel\">")

      assert [{"class", {:string, "panel", %{}}, %{}}] = attrs
    end

    test "raise on missing value" do
      message = "nofile:2:9: expected attribute value or expression after `=`"

      assert_raise ParseError, message, fn ->
        tokenize!("""
        <div
          class=>\
        """)
      end

      message = "nofile:1:13: expected attribute value or expression after `=`"

      assert_raise ParseError, message, fn ->
        tokenize!(~S(<div class= >))
      end

      message = "nofile:1:12: expected attribute value or expression after `=`"

      assert_raise ParseError, message, fn ->
        tokenize!("<div class=")
      end
    end

    test "raise on missing attribure name" do
      assert_raise ParseError, "nofile:2:8: expected attribute name", fn ->
        tokenize!("""
        <div>
          <div ="panel">\
        """)
      end

      assert_raise ParseError, "nofile:1:6: expected attribute name", fn ->
        tokenize!(~S(<div = >))
      end

      assert_raise ParseError, "nofile:1:6: expected attribute name", fn ->
        tokenize!(~S(<div / >))
      end
    end
  end

  describe "boolean attributes" do
    test "represented as {name, nil}" do
      attrs = tokenize_attrs("<div hidden>")

      assert [{"hidden", nil, %{}}] = attrs
    end

    test "multiple attributes" do
      attrs = tokenize_attrs("<div hidden selected>")

      assert [{"hidden", nil, %{}}, {"selected", nil, %{}}] = attrs
    end

    test "with space after" do
      attrs = tokenize_attrs("<div hidden >")

      assert [{"hidden", nil, %{}}] = attrs
    end

    test "in self close tag" do
      attrs = tokenize_attrs("<div hidden/>")

      assert [{"hidden", nil, %{}}] = attrs
    end

    test "in self close tag with space after" do
      attrs = tokenize_attrs("<div hidden />")

      assert [{"hidden", nil, %{}}] = attrs
    end
  end

  describe "attributes as double quoted string" do
    test "value is represented as {:string, value, meta}}" do
      attrs = tokenize_attrs(~S(<div class="panel">))

      assert [{"class", {:string, "panel", %{delimiter: ?"}}, %{}}] = attrs
    end

    test "multiple attributes" do
      attrs = tokenize_attrs(~S(<div class="panel" style="margin: 0px;">))

      assert [
               {"class", {:string, "panel", %{delimiter: ?"}}, %{}},
               {"style", {:string, "margin: 0px;", %{delimiter: ?"}}, %{}}
             ] = attrs
    end

    test "value containing single quotes" do
      attrs = tokenize_attrs(~S(<div title="i'd love to!">))

      assert [{"title", {:string, "i'd love to!", %{delimiter: ?"}}, %{}}] = attrs
    end

    test "value containing line breaks" do
      tokens =
        tokenize!("""
        <div title="first
          second
        third"><span>\
        """)

      assert [
               {:tag_open, "div", [{"title", {:string, "first\n  second\nthird", _meta}, %{}}],
                %{}},
               {:tag_open, "span", [], %{line: 3, column: 9}}
             ] = tokens
    end

    test "compute line and columns" do
      attrs =
        tokenize_attrs("""
        <div
          title="first
            second
        third">\
        """)

      assert [
               {"title", {:string, _, %{line: 2, column: 10, line_end: 4, column_end: 6}}, %{}}
             ] = attrs
    end

    test "raise on incomplete attribute value (EOF)" do
      assert_raise ParseError, "nofile:2:15: expected closing `\"` for attribute value", fn ->
        tokenize!("""
        <div
          class="panel\
        """)
      end
    end
  end

  describe "attributes as single quoted string" do
    test "value is represented as {:string, value, meta}}" do
      attrs = tokenize_attrs(~S(<div class='panel'>))

      assert [{"class", {:string, "panel", %{delimiter: ?'}}, %{}}] = attrs
    end

    test "multiple attributes" do
      attrs = tokenize_attrs(~S(<div class='panel' style='margin: 0px;'>))

      assert [
               {"class", {:string, "panel", %{delimiter: ?'}}, %{}},
               {"style", {:string, "margin: 0px;", %{delimiter: ?'}}, %{}}
             ] = attrs
    end

    test "value containing double quotes" do
      attrs = tokenize_attrs(~S(<div title='Say "hi!"'>))

      assert [{"title", {:string, ~S(Say "hi!"), %{delimiter: ?'}}, %{}}] = attrs
    end

    test "value containing line breaks" do
      tokens =
        tokenize!("""
        <div title='first
          second
        third'><span>\
        """)

      assert [
               {:tag_open, "div", [{"title", {:string, "first\n  second\nthird", _meta}, %{}}],
                %{}},
               {:tag_open, "span", [], %{line: 3, column: 9}}
             ] = tokens
    end

    test "compute line and columns" do
      attrs =
        tokenize_attrs("""
        <div
          title='first
            second
        third'>\
        """)

      assert [
               {"title", {:string, _, %{line: 2, column: 10, line_end: 4, column_end: 6}}, %{}}
             ] = attrs
    end

    test "raise on incomplete attribute value (EOF)" do
      assert_raise ParseError, "nofile:2:15: expected closing `\'` for attribute value", fn ->
        tokenize!("""
        <div
          class='panel\
        """)
      end
    end
  end

  describe "attributes as unquoted strings" do
    test "value is represented as {:string, value, meta}" do
      attrs = tokenize_attrs(~S(<div disabled=true>))
      assert [{"disabled", {:string, "true", %{delimiter: nil}}, %{}}] = attrs
    end

    test "compute line and columns" do
      attrs =
        tokenize_attrs("""
        <div
          disabled=true
          hidden=false
        >\
        """)

      assert [
               {"disabled",
                {_, _, %{delimiter: nil, column: 12, column_end: 16, line: 2, line_end: 2}}, %{}},
               {"hidden",
                {_, _, %{delimiter: nil, column: 10, column_end: 15, line: 3, line_end: 3}}, %{}}
             ] = attrs
    end
  end

  describe "attributes as expressions" do
    test "value is represented as {:expr, value, meta}" do
      attrs = tokenize_attrs(~S(<div class={@class}>))

      assert [{"class", {:expr, "@class", %{line: 1, column: 13}}, %{}}] = attrs
    end

    test "multiple attributes" do
      attrs = tokenize_attrs(~S(<div class={@class} style={@style}>))

      assert [
               {"class", {:expr, "@class", %{}}, %{}},
               {"style", {:expr, "@style", %{}}, %{}}
             ] = attrs
    end

    test "double quoted strings inside expression" do
      attrs = tokenize_attrs(~S(<div class={"text"}>))

      assert [{"class", {:expr, ~S("text"), %{}}, %{}}] = attrs
    end

    test "value containing curly braces" do
      attrs = tokenize_attrs(~S(<div class={ [{:active, @active}] }>))

      assert [{"class", {:expr, " [{:active, @active}] ", %{}}, %{}}] = attrs
    end

    test "ignore escaped curly braces inside elixir strings" do
      attrs = tokenize_attrs(~S(<div class={"\{hi"}>))

      assert [{"class", {:expr, ~S("\{hi"), %{}}, %{}}] = attrs

      attrs = tokenize_attrs(~S(<div class={"hi\}"}>))

      assert [{"class", {:expr, ~S("hi\}"), %{}}, %{}}] = attrs
    end

    test "compute line and columns" do
      attrs =
        tokenize_attrs("""
        <div
          class={@class}
            style={
              @style
            }
          title={@title}
        >\
        """)

      assert [
               {"class", {:expr, _, %{line: 2, column: 10, line_end: 2, column_end: 16}}, %{}},
               {"style", {:expr, _, %{line: 3, column: 12, line_end: 5, column_end: 5}}, %{}},
               {"title", {:expr, _, %{line: 6, column: 10, line_end: 6, column_end: 16}}, %{}}
             ] = attrs
    end

    test "raise on incomplete attribute expression (EOF)" do
      assert_raise ParseError, "nofile:2:15: expected closing `}` for expression", fn ->
        tokenize!("""
        <div
          class={panel\
        """)
      end
    end
  end

  describe "root attributes" do
    test "represented as {:root, value, meta}" do
      attrs = tokenize_attrs("<div {@attrs}>")

      assert [{:root, {:expr, "@attrs", %{}}, %{}}] = attrs
    end

    test "with space after" do
      attrs = tokenize_attrs("<div {@attrs} >")

      assert [{:root, {:expr, "@attrs", %{}}, %{}}] = attrs
    end

    test "with line break after" do
      attrs = tokenize_attrs("<div {@attrs}\n>")

      assert [{:root, {:expr, "@attrs", %{}}, %{}}] = attrs
    end

    test "in self close tag" do
      attrs = tokenize_attrs("<div {@attrs}/>")

      assert [{:root, {:expr, "@attrs", %{}}, %{}}] = attrs
    end

    test "in self close tag with space after" do
      attrs = tokenize_attrs("<div {@attrs} />")

      assert [{:root, {:expr, "@attrs", %{}}, %{}}] = attrs
    end

    test "multiple values among other attributes" do
      attrs = tokenize_attrs("<div class={@class} {@attrs1} hidden {@attrs2}/>")

      assert [
               {"class", {:expr, "@class", %{}}, %{}},
               {:root, {:expr, "@attrs1", %{}}, %{}},
               {"hidden", nil, %{}},
               {:root, {:expr, "@attrs2", %{}}, %{}}
             ] = attrs
    end

    test "compute line and columns" do
      attrs =
        tokenize_attrs("""
        <div
          {@root1}
            {
              @root2
            }
          {@root3}
        >\
        """)

      assert [
               {:root, {:expr, "@root1", %{line: 2, column: 4}}, %{}},
               {:root, {:expr, "\n      @root2\n    ", %{line: 3, column: 6}}, %{}},
               {:root, {:expr, "@root3", %{line: 6, column: 4}}, %{}}
             ] = attrs
    end

    test "raise on incomplete expression (EOF)" do
      assert_raise ParseError, "nofile:2:10: expected closing `}` for expression", fn ->
        tokenize!("""
        <div
          {@attrs\
        """)
      end
    end
  end

  describe "closing tag" do
    test "represented as {:tag_close, name, meta}" do
      tokens = tokenize!("</div>")
      assert [{:tag_close, "div", %{column: 3, line: 1}}] = tokens
    end

    test "compute line and columns" do
      tokens =
        tokenize!("""
        <div>
        </div><br>\
        """)

      assert [
               {:tag_open, "div", [], _meta},
               {:text, _},
               {:tag_close, "div", %{column: 3, line: 2}},
               {:tag_open, "br", [], %{line: 2, column: 8}}
             ] = tokens
    end

    test "raise on missing closing `>`" do
      assert_raise ParseError, "nofile:2:6: expected closing `>`", fn ->
        tokenize!("""
        <div>
        </div text\
        """)
      end
    end
  end

  test "mixing text and tags" do
    tokens =
      tokenize!("""
      text before
      <div>
        text
      </div>
      text after
      """)

    assert [
             {:text, "text before\n"},
             {:tag_open, "div", [], %{}},
             {:text, "\n  text\n"},
             {:tag_close, "div", %{column: 3, line: 4}},
             {:text, "\ntext after\n"}
           ] = tokens
  end

  describe "macro components" do
    test "do not tokenize its contents" do
      tokens =
        tokenize!("""
        <#Macro>
        text before
        <div>
          text
        </div>
        text after
        </#Macro>
        """)

      assert [
               {:tag_open, "#Macro", [], %{line: 1, column: 2}},
               {:text, "\ntext before\n<div>\n  text\n</div>\ntext after\n"},
               {:tag_close, "#Macro", %{line: 7, column: 3}},
               {:text, "\n"}
             ] = tokens
    end

    test "<#raw> multi lines is treated like a macro" do
      tokens =
        tokenize!("""
        <#raw>
          <div>
            { @id }
          </div>
        </#raw>
        """)

      assert [
               {:tag_open, "#raw", [], %{line: 1, column: 2}},
               {:text, "\n  <div>\n    { @id }\n  </div>\n"},
               {:tag_close, "#raw", %{line: 5, column: 3}},
               {:text, "\n"}
             ] = tokens
    end

    test "<#raw> single line is treated like a macro" do
      tokens =
        tokenize!("""
        <#raw><div>{ @id }</div></#raw>
        """)

      assert [
               {:tag_open, "#raw", [], %{line: 1, column: 2}},
               {:text, "<div>{ @id }</div>"},
               {:tag_close, "#raw", %{line: 1, column: 27}},
               {:text, "\n"}
             ] = tokens
    end
  end

  defp tokenize_attrs(code) do
    [{:tag_open, "div", attrs, %{}}] = tokenize!(code)
    attrs
  end
end
