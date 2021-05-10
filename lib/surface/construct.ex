defmodule Surface.Construct do
  defmodule SubBlock do
    @moduledoc """
    ## Properties
        * `:name` - the sub block name
        * `:attributes` - a list of attributes
        * `:body` - a list of ast nodes representing the sub block's body
        * `:meta` - compilation meta data
        * `:debug` - keyword list indicating when debug information should be printed during compilation
    """
    defstruct [:name, :attributes, :body, :meta, debug: []]

    @type t :: %__MODULE__{
            name: binary(),
            attributes: list(Surface.AST.Attribute.t()),
            body: list(Surface.AST.t()),
            debug: list(atom()),
            meta: Surface.AST.Meta.t()
          }
  end

  @callback validate_subblock(name :: :default | binary()) :: :ok | {:error, binary()}
  @callback attribute_type(
              block :: :default | binary(),
              name :: :root | binary(),
              meta :: Surface.AST.Meta.t()
            ) :: atom()
  @callback process(
              attributes :: list(Surface.AST.Attribute.t()),
              body :: list(Surface.AST.t()),
              sub_blocks :: list(SubBlock.t()),
              meta :: Surface.AST.Meta.t()
            ) :: Surface.AST.t()

  defmacro __using__(_opts \\ []) do
    quote do
      @behaviour Surface.Construct

      def attribute_type(_, _, _), do: :any

      defoverridable attribute_type: 3
    end
  end
end
