defmodule Surface.CompilerTest.DebugAnnotationsUtil do
  def debug_heex_annotations_supported? do
    Application.spec(:phoenix_live_view, :vsn)
    |> to_string()
    |> Version.parse!()
    |> Version.compare("0.20.0") != :lt
  end

  defmacro use_component() do
    if __MODULE__.debug_heex_annotations_supported?() do
      quote do
        use Surface.Component, debug_heex_annotations: true
      end
    else
      quote do
        use Surface.Component
      end
    end
  end
end
