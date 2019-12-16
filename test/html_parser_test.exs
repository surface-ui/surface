defmodule HTMLParserTest do
  use ExUnit.Case

  import HTMLParser

  describe "HTML only" do
    test "single node" do
      assert parse("<foo>bar</foo>") ==
               {:ok, [{"foo", [], ["bar"]}]}
    end

    test "Elixir node" do
      assert parse("<Foo.Bar>bar</Foo.Bar>") ==
               {:ok, [{"Foo.Bar", [], ["bar"]}]}
    end

    test "mixed nodes" do
      assert parse("<foo>one<bar>two</bar>three</foo>") ==
               {:ok, [{"foo", [], ["one", {"bar", [], ["two"]}, "three"]}]}
    end

    test "self-closing nodes" do
      assert parse("<foo>one<bar><bat/></bar>three</foo>") ==
               {:ok, [{"foo", [], ["one", {"bar", [], [{"bat", [], []}]}, "three"]}]}
    end
  end

  describe "interpolation" do
    test "single curly bracket" do
      assert parse("<foo>{bar}</foo>") ==
               {:ok, [{"foo", [], ["{", "bar}"]}]}
    end

    test "double curly bracket" do
      assert parse("<foo>{{baz}}</foo>") ==
               {:ok, [{"foo", '', [{:interpolation, "baz"}]}]}
    end

    test "mixed curly bracket" do
      assert parse("<foo>bar{{baz}}bat</foo>") ==
               {:ok, [{"foo", '', ["bar", {:interpolation, "baz"}, "bat"]}]}
    end

    test "single-closing curly bracket" do
      assert parse("<foo>bar{{ 'a}b' }}bat</foo>") ==
               {:ok, [{"foo", [], ["bar", {:interpolation, " 'a}b' "}, "bat"]}]}
    end
  end

  describe "with macros" do
    test "single node" do
      assert parse("<#foo>bar</#foo>") ==
               {:ok, [{"#foo", [], ["bar"]}]}
    end

    test "mixed nodes" do
      assert parse("<#foo>one<bar>two</baz>three</#foo>") ==
               {:ok, [{"#foo", [], ["one<bar>two</baz>three"]}]}

      assert parse("<#foo>one<#bar>two</#baz>three</#foo>") ==
               {:ok, [{"#foo", [], ["one<#bar>two</#baz>three"]}]}

      assert parse("<#foo>one<bar>two<baz>three</#foo>") ==
               {:ok, [{"#foo", [], ["one<bar>two<baz>three"]}]}

      assert parse("<#foo>one</bar>two</baz>three</#foo>") ==
               {:ok, [{"#foo", [], ["one</bar>two</baz>three"]}]}
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
end
