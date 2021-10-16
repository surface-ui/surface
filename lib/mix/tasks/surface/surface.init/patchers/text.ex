defmodule Mix.Tasks.Surface.Init.Patchers.Text do
  @moduledoc false

  def append_line(code, text, already_pached_text) do
    already_pached_regex = Regex.compile!("^#{Regex.escape(already_pached_text)}$", "m")

    if Regex.match?(already_pached_regex, code) do
      {:already_patched, code}
    else
      {:patched, String.trim_trailing(code) <> "\n\n#{text}"}
    end
  end
end
