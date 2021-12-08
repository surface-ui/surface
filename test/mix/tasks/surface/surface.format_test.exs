defmodule Surface.Mix.Tasks.FormatTest do
  use ExUnit.Case

  import ExUnit.CaptureIO

  describe "reads from stdin and prints to stdout with formatter" do
    test "handles an Elixir file" do
      file = """
      defmodule Card do
        use Surface.Component

        def render(assigns) do
          ~F\"\"\"
          <div>
          <ul>
          <li>
          <a>
          Hello
          </a>
          </li>
          </ul>
          </div>
          \"\"\"
        end
      end
      """

      formatted = """
      defmodule Card do
        use Surface.Component

        def render(assigns) do
          ~F\"\"\"
          <div>
            <ul>
              <li>
                <a>
                  Hello
                </a>
              </li>
            </ul>
          </div>
          \"\"\"
        end
      end
      """

      assert formatted ==
               capture_io(file, fn ->
                 Mix.Tasks.Surface.Format.run(["-"])
               end)
    end

    test "handles a Surface file" do
      file = """
      <div>
      <ul>
      <li>
      <a>
      Hello
      </a>
      </li>
      </ul>
      </div>
      """

      formatted = """
      <div>
        <ul>
          <li>
            <a>
              Hello
            </a>
          </li>
        </ul>
      </div>
      """

      assert formatted ==
               capture_io(file, fn ->
                 Mix.Tasks.Surface.Format.run(["-"])
               end)
    end
  end
end
