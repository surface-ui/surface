defmodule Surface.CompilerTest.DebugAnnotationsUtil do
  def debug_heex_annotations_supported? do
    Application.spec(:phoenix_live_view, :vsn)
    |> to_string()
    |> Version.parse!()
    |> Version.compare("0.20.0") != :lt
  end
end
