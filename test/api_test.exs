defmodule Surface.DataTest do
  use ExUnit.Case

  test "raise error at the right line" do
    code = "property label, :unknown_type"
    message = ~r/code:4/

    assert_raise(CompileError, message, fn ->
      eval(code)
    end)
  end

  test "validate type" do
    code = "property label, {a, b}"
    message = ~r/invalid type {a, b} for property label. Expected one of \[:any/

    assert_raise(CompileError, message, fn ->
      eval(code)
    end)
  end

  test "validate options" do
    code = "property label, :string, {a, b}"
    message = ~r/invalid options for property label. Expected a keyword list of options, got: {a, b}/

    assert_raise(CompileError, message, fn ->
      eval(code)
    end)
  end

  test "validate type options" do
    code = "data label, :string, a: 1"
    message = ~r/unknown option for type :string/

    assert_raise(CompileError, message, fn ->
      eval(code)
    end)

    code = "data label, :string, a: 1, b: 2"
    message = ~r/unknown options for type :string/

    assert_raise(CompileError, message, fn ->
      eval(code)
    end)
  end

  describe "property" do

    test "validate name" do
      code = "property {a, b}, :string"
      message = ~r/invalid property name. Expected a variable name, got: {a, b}/

      assert_raise(CompileError, message, fn ->
        eval(code)
      end)
    end

    test "common type options" do
      code = "property count, :integer, required: false, default: 0, values: [0, 1, 2]"
      assert eval(code) == :ok
    end

    test "validate unknown type options" do
      code = "property label, :string, a: 1"
      message = ~r/unknown option for type :string. Expected any of \[:required, :default, :values\]. Got: :a/

      assert_raise(CompileError, message, fn ->
        eval(code)
      end)
    end
  end

  describe "data" do

    test "validate name" do
      code = "data {a, b}, :string"
      message = ~r/invalid data name. Expected a variable name, got: {a, b}/

      assert_raise(CompileError, message, fn ->
        eval(code)
      end)
    end

    test "common type options" do
      code = "data count, :integer, default: 0, values: [0, 1, 2]"
      assert eval(code) == :ok
    end

    test "validate unknown type options" do
      code = "data label, :string, a: 1"
      message = ~r/unknown option for type :string. Expected any of \[:default, :values\]. Got: :a/

      assert_raise(CompileError, message, fn ->
        eval(code)
      end)
    end
  end

  defp eval(code) do
    id = :erlang.unique_integer([:positive]) |> to_string()
    module = "TestLiveComponent_#{id}"

    comp_code = """
    defmodule #{module} do
      use Surface.LiveComponent

      #{code}

      def render(assigns) do
        ~H(<div></div>)
      end
    end
    """

    {{:module, _, _, _}, _} = Code.eval_string(comp_code, [], file: "code")
    :ok
  end
end
