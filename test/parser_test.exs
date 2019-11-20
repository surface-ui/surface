defmodule ParserTest do
  use ExUnit.Case
  alias Surface.Translator.{Parser}

  test "parse html tag" do
    code = ~S(<span label="My label 1" />)
    [node] = Parser.parse(code, 1)

    assert node == {"span", [{"label", 'My label 1', 1}], [], %{line: 1}}
  end

  test "parse html tag with children" do
    code = ~S(<div><span/><span/></div>)

    tree = Parser.parse(code, 1)

    assert tree == [
      {"div", [], [
        {"span", [], [], %{line: 1}},
        {"span", [], [], %{line: 1}},
      ], %{line: 1}}
    ]
  end

  test "parse component" do
    code = ~S(<MyComponent label="My label"/>)
    [node] = Parser.parse(code, 1)

    assert node == {"MyComponent", [{"label", 'My label', 1}], [], %{line: 1}}
  end

  test "parse component with children" do
    code = ~S(<MyComponent><span /><span /></MyComponent>)
    [node] = Parser.parse(code, 1)

    assert node == {
      "MyComponent",
      [],
      [
        {"span", [], [], %{line: 1}},
        {"span", [], [], %{line: 1}}
      ],
      %{line: 1}
    }
  end

  test "parsing with spaces and line break" do
    code = """
    <div>
      <span />
      <span />
    </div>
    """

    tree = Parser.parse(code, 1)

    assert tree == [
      {"div", [], [
        10,
        32,
        32,
        {"span", [], [], %{line: 2}},
        "\n  ",
        {"span", [], [], %{line: 3}},
        "\n"
      ], %{line: 1}},
      "\n"
    ]
  end

  describe "macros" do
    test "single node" do
      assert Parser.parse("<#Foo>bar</#Foo>", 1) == [
        {"#Foo", [], ["bar"], %{line: 1}}
      ]
    end

    test "mixed nodes" do
      assert Parser.parse("<#Foo>one<bar>two</baz>three</#Foo>", 1) == [
        {"#Foo", [], ["one<bar>two</baz>three"], %{line: 1}}
      ]

      assert Parser.parse("<#Foo>one<#Bar>two</#Baz>three</#Foo>", 1) == [
        {"#Foo", [], ["one<#Bar>two</#Baz>three"], %{line: 1}}
      ]

      assert Parser.parse("<#Foo>one<bar>two<baz>three</#Foo>", 1) == [
        {"#Foo", [], ["one<bar>two<baz>three"], %{line: 1}}
      ]

      assert Parser.parse("<#Foo>one</bar>two</baz>three</#Foo>", 1) == [
        {"#Foo", [], ["one</bar>two</baz>three"], %{line: 1}}
      ]
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

      [{_, _, children, _} | _] = Parser.parse(code, 1)
      {_, _, _, meta} = Enum.at(children, 4)
      assert meta.line == 3
    end

    test "do not perform interpolation for inner content" do
      assert Parser.parse("<#Foo>one {{ @var }} two</#Foo>", 1) == [
        {"#Foo", [], ["one {{ @var }} two"], %{line: 1}}
      ]
    end
  end
end
