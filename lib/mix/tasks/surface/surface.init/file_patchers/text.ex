defmodule Mix.Tasks.Surface.Init.FilePatchers.Text do
  @moduledoc false

  def append_line(code, text, already_patched_text) do
    already_patched_regex = Regex.compile!("^#{Regex.escape(already_patched_text)}$", "m")

    if Regex.match?(already_patched_regex, code) do
      {:already_patched, code}
    else
      {:patched, String.trim_trailing(code) <> "\n\n#{text}"}
    end
  end

  def prepend_text(code, text, already_patched_text) do
    if String.contains?(code, already_patched_text) do
      {:already_patched, code}
    else
      {:patched, "#{text}\n\n" <> String.trim_leading(code)}
    end
  end

  def replace_line_text(code, line_text, replacement) do
    already_patched? = Regex.match?(to_regex(replacement), code)
    line_text_regex = to_regex(line_text)
    patchable? = Regex.match?(line_text_regex, code)

    cond do
      already_patched? ->
        {:already_patched, code}

      patchable? ->
        {:patched, Regex.replace(line_text_regex, code, replacement)}

      true ->
        {:cannot_patch, code}
    end
  end

  def replace_text(code, text, replacement, already_patched_text) do
    already_patched? = String.contains?(code, already_patched_text)
    patchable? = String.contains?(code, text)

    cond do
      already_patched? ->
        {:already_patched, code}

      patchable? ->
        {:patched, String.replace(code, text, replacement)}

      true ->
        {:cannot_patch, code}
    end
  end

  def remove_text(code, text) do
    if String.contains?(code, text) do
      {:patched, String.replace(code, text, "")}
    else
      {:already_patched, code}
    end
  end

  defp to_regex(string) do
    Regex.compile!("^#{Regex.escape(string)}$", "m")
  end
end
