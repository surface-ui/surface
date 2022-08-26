defmodule Surface.Formatter.PluginTest do
  use ExUnit.Case
  @moduletag :plugin

  # Write a unique file and .formatter.exs for a test, run `mix format` on the
  # file, and assert whether the input matches the expected output
  defp assert_formatter_output(filename, dot_formatter_opts \\ [], input_ex, expected) do
    ex_path = Path.join(System.tmp_dir(), filename)
    dot_formatter_path = ex_path <> ".formatter.exs"
    dot_formatter_opts = Keyword.put(dot_formatter_opts, :plugins, [Surface.Formatter.Plugin])

    on_exit(fn ->
      File.rm(ex_path)
      File.rm(dot_formatter_path)
    end)

    File.write!(ex_path, input_ex)
    File.write!(dot_formatter_path, inspect(dot_formatter_opts))

    Mix.Tasks.Format.run([ex_path, "--dot-formatter", dot_formatter_path])

    assert File.read!(ex_path) == expected
  end

  defp assert_formatter_doesnt_change(filename, dot_formatter_opts \\ [], code) do
    assert_formatter_output(filename, dot_formatter_opts, code, code)
  end

  test ".sface files are formatted" do
    assert_formatter_output(
      "sface_files.sface",
      """
      <div>
        </div>
      """,
      """
      <div>
      </div>
      """
    )
  end

  test "~F sigils are formatted" do
    assert_formatter_output(
      "f_sigils.ex",
      """
      defmodule Foo do
        def bar do
          ~F\"""
            <div>
              </div>
          \"\"\"
        end
      end
      """,
      """
      defmodule Foo do
        def bar do
          ~F\"""
          <div>
          </div>
          \"\"\"
        end
      end
      """
    )
  end

  test ":surface_line_length overrides :line_length" do
    assert_formatter_output(
      "surface_line_length.ex",
      [line_length: 200, surface_line_length: 50],
      """
      defmodule Foo do
        def render(assigns) do
          ~F\"""
          <Component a="12345678901234567890" b="12345678901234567890" c="12345678901234567890" d="12345678901234567890" e="12345678901234567890" />
          \"\"\"
        end
      end
      """,
      """
      defmodule Foo do
        def render(assigns) do
          ~F\"""
          <Component
            a="12345678901234567890"
            b="12345678901234567890"
            c="12345678901234567890"
            d="12345678901234567890"
            e="12345678901234567890"
          />
          \"\"\"
        end
      end
      """
    )
  end

  test "omitting :line_length and :surface_line_length defaults to default line_length" do
    # reproducing a bug that occurred when both were omitted, with an Elixir expression
    assert_formatter_output(
      "config.sface",
      [],
      """
        {@foo}
      """,
      """
      {@foo}
      """
    )
  end

  test ":hook directive without any attribute" do
    assert_formatter_doesnt_change(
      "sface_files.sface",
      """
      <div :hook />
      """
    )
  end
end
