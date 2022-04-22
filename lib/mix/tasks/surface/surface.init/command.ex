defmodule Mix.Tasks.Surface.Init.Command do
  @callback file_patchers(assigns :: map()) :: [map()]
  @callback create_files(assigns :: map()) :: list()
end
