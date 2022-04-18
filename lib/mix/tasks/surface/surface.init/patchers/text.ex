defmodule Mix.Tasks.Surface.Init.Patchers.Text do
  @moduledoc false

  def append_line(code, text, already_patched_text) do
    already_patched_regex = Regex.compile!("^#{Regex.escape(already_patched_text)}$", "m")

    if Regex.match?(already_patched_regex, code) do
      {:already_patched, code}
    else
      {:patched, String.trim_trailing(code) <> "\n\n#{text}"}
    end
  end
end
