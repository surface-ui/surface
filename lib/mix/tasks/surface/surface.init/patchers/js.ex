defmodule Mix.Tasks.Surface.Init.Patchers.JS do
  @moduledoc false

  def add_import(code, import_code) do
    already_patched? = Regex.match?(to_regex(import_code), code)
    import_toolbar_regex = to_regex(~S[import topbar from "../vendor/topbar"])
    patchable? = Regex.match?(import_toolbar_regex, code)

    cond do
      already_patched? ->
        {:already_patched, code}

      patchable? ->
        {:patched, Regex.replace(import_toolbar_regex, code, ~s[\\0\n#{import_code}])}

      true ->
        {:cannot_patch, code}
    end
  end

  defp to_regex(string) do
    Regex.compile!("^#{Regex.escape(string)}$", "m")
  end
end
