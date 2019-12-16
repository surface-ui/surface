defmodule HTMLParserTest do
  use ExUnit.Case

  import HTMLParser

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
               {:ok, [{"foo", [], ["one", {"bar", [], ["two"], %{line: 1}}, "three"], %{line: 1}}]}
    end

    test "self-closing nodes" do
      assert parse("<foo>one<bar><bat/></bar>three</foo>") ==
               {:ok, [{"foo", [], ["one", {"bar", [], [{"bat", [], [], %{line: 1}}], %{line: 1}}, "three"], %{line: 1}}]}
    end
  end

  describe "interpolation" do
    test "single curly bracket" do
      assert parse("<foo>{bar}</foo>") ==
               {:ok, [{"foo", [], ["{", "bar}"], %{line: 1}}]}
    end

    test "double curly bracket" do
      assert parse("<foo>{{baz}}</foo>") ==
               {:ok, [{"foo", '', [{:interpolation, "baz"}], %{line: 1}}]}
    end

    test "mixed curly bracket" do
      assert parse("<foo>bar{{baz}}bat</foo>") ==
               {:ok, [{"foo", '', ["bar", {:interpolation, "baz"}, "bat"], %{line: 1}}]}
    end

    test "single-closing curly bracket" do
      assert parse("<foo>bar{{ 'a}b' }}bat</foo>") ==
               {:ok, [{"foo", [], ["bar", {:interpolation, " 'a}b' "}, "bat"], %{line: 1}}]}
    end
  end

  describe "with macros" do
    test "single node" do
      assert parse("<#foo>bar</#foo>") ==
               {:ok, [{"#foo", [], ["bar"], %{line: 1}}]}
    end

    test "mixed nodes" do
      assert parse("<#foo>one<bar>two</baz>three</#foo>") ==
               {:ok, [{"#foo", [], ["one<bar>two</baz>three"], %{line: 1}}]}

      assert parse("<#foo>one<#bar>two</#baz>three</#foo>") ==
               {:ok, [{"#foo", [], ["one<#bar>two</#baz>three"], %{line: 1}}]}

      assert parse("<#foo>one<bar>two<baz>three</#foo>") ==
               {:ok, [{"#foo", [], ["one<bar>two<baz>three"], %{line: 1}}]}

      assert parse("<#foo>one</bar>two</baz>three</#foo>") ==
               {:ok, [{"#foo", [], ["one</bar>two</baz>three"], %{line: 1}}]}
    end
  end

  describe "errors on" do
    test "invalid opening tag" do
      assert parse("<>bar</>") ==
               {:error, "expected opening HTML tag"}
    end

    test "invalid closing tag" do
      assert parse("<foo>bar</></foo>") ==
               {:error, "expected closing tag for \"foo\""}
    end

    test "tag mismatch" do
      assert parse("<foo>bar</baz>") ==
               {:error, "closing tag \"baz\" did not match opening tag \"foo\""}
    end

    test "before tag content" do
      assert parse("oops<foo>bar</foo>") ==
               {:error, "expected opening HTML tag"}
    end

    test "after tag content" do
      assert parse("<foo>bar</foo>oops") ==
               {:error, "expected end of string, found: \"oops\""}
    end

    test "incomplete tag content" do
      assert parse("<foo>bar") ==
               {:error, "expected closing tag for \"foo\""}
    end

    test "incomplete macro content" do
      assert parse("<#foo>bar</#bar>") ==
               {:error, "expected closing tag for \"#foo\""}
    end

    test "non-closing interpolation" do
      assert parse("<foo>{{bar</foo>") ==
               {:error, "expected closing for interpolation"}
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

      attributes = [{"prop1", 'value1', 2}, {"prop2", 'value2', 3}]
      children = [
        "\n  bar\n  ",
        {"div", [], [{:interpolation, " var "}], %{line: 6}},
        "\n"
      ]

      assert parse(code) == {:ok, [{"foo", attributes, children, %{line: 1}}]}
    end

    test "self-closing nodes" do
      code = """
      <foo
        prop1="value1"
        prop2="value2"
      />
      """

      attributes = [{"prop1", 'value1', 2}, {"prop2", 'value2', 3}]

      assert parse(code) == {:ok, [{"foo", attributes, [], %{line: 1}}]}
    end
  end
end
