defmodule Surface.DataTest do
  use ExUnit.Case

  test "raise error at the right line" do
    code = "data label, :unknown_type"
    message = ~r/code:4/

    assert_raise(CompileError, message, fn ->
      eval(code)
    end)
  end

  test "validate name" do
    code = "data {a, b}, :string"
    message = ~r/invalid data name. Expected a variable name, got: {a, b}/

    assert_raise(CompileError, message, fn ->
      eval(code)
    end)
  end

  test "validate type" do
    code = "data label, {a, b}"
    message = ~r/invalid type {a, b} for data label. Expected one of \[:any/

    assert_raise(CompileError, message, fn ->
      eval(code)
    end)
  end

  test "validate options" do
    code = "data label, :string, {a, b}"
    message = ~r/invalid options for data label. Expected a keyword list of options, got: {a, b}/

    assert_raise(CompileError, message, fn ->
      eval(code)
    end)
  end

  test "validate type options" do
    code = "data label, :string, a: 1"
    message = ~r/unknown option for type :string. Expected any of \[:default, :values\]. Got: :a/

    assert_raise(CompileError, message, fn ->
      eval(code)
    end)

    code = "data label, :string, a: 1, b: 2"
    message = ~r/unknown options for type :string. Expected any of \[:default, :values\]. Got: \[:a, :b\]/

    assert_raise(CompileError, message, fn ->
      eval(code)
    end)
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
