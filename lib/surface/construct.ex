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
    defstruct [:name, :attributes, :body, :meta]

    @type t :: %__MODULE__{
            name: binary(),
            attributes: list(Surface.AST.Attribute.t()),
            body: list(Surface.AST.t()),
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
      import Surface.Construct, only: [find_prop_value: 3]

      def attribute_type(_, _, _), do: :any

      defoverridable attribute_type: 3
    end
  end

  def find_prop_value(attributes, name, default, opts \\ []) do
    Enum.find_value(attributes, default, fn attr ->
      if attr.name == name || (opts[:root] && attr.name == :root) do
        attr.value
      end
    end)
  end
end
