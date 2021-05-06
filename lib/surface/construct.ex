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

  @callback valid_subblocks() :: list(:default | binary())
  @callback process(
              attributes :: list(Surface.AST.Attribute.t()),
              body :: list(Surface.AST.t()),
              sub_blocks :: list(SubBlock.t()),
              meta :: Surface.AST.Meta.t()
            ) :: Surface.AST.t()
end
