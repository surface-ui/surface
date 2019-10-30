defmodule ParserTest do
  use ExUnit.Case
  alias Surface.Translator.{Parser, TagNode, ComponentNode}

  test "parse html tag" do
    code = ~S(<span label="My label 1" />)
    [node] = Parser.parse(code, 1)

    assert node == %TagNode{name: "span", attributes: [{"label", 'My label 1', 1}], children: [], line: 1}
  end

  test "parse html tag with children" do
    code = ~S(<div><span/><span/></div>)

    tree = Parser.parse(code, 1)

    assert tree == [
      %TagNode{name: "div", line: 1, attributes: [], children: [
        %TagNode{name: "span", line: 1, attributes: [], children: []},
        %TagNode{name: "span", line: 1, attributes: [], children: []},
      ]}
    ]
  end

  test "parse component" do
    code = ~S(<MyComponent label="My label"/>)
    [node] = Parser.parse(code, 1)

    assert node == %ComponentNode{
      name: "MyComponent",
      attributes: [{"label", 'My label', 1}],
      line: 1,
      children: []
    }
  end

  test "parse component with children" do
    code = ~S(<MyComponent><span /><span /></MyComponent>)
    [node] = Parser.parse(code, 1)

    assert node == %ComponentNode{
      name: "MyComponent",
      attributes: [],
      line: 1,
      children: [
        %TagNode{name: "span", attributes: [], children: [], line: 1},
        %TagNode{name: "span", attributes: [], children: [], line: 1}
      ]
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
      %TagNode{name: "div", line: 1, attributes: [], children: [
        10,
        32,
        32,
        %TagNode{name: "span", line: 2, attributes: [], children: []},
        "\n  ",
        %TagNode{name: "span", line: 3, attributes: [], children: []},
        "\n"
      ]},
      "\n"
    ]
  end
end

