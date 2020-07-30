defmodule Surface.AST do
  @type t ::
          Surface.AST.Text.t()
          | Surface.AST.Interpolation.t()
          | Surface.AST.Tag.t()
          | Surface.AST.Template.t()
          | Surface.AST.Slot.t()
          | Surface.AST.Component.t()
          | Surface.AST.Error.t()
end

defmodule Surface.AST.Meta do
  @derive {Inspect, only: [:line, :module, :node_alias, :file, :line_offset]}
  defstruct [:line, :module, :node_alias, :line_offset, :file, :caller]

  @type t :: %__MODULE__{
          line: non_neg_integer(),
          line_offset: non_neg_integer(),
          module: atom(),
          node_alias: binary() | nil,
          caller: Macro.Env.t(),
          file: binary()
        }
end

defmodule Surface.AST.Directive do
  defstruct [:module, :name, :value, :meta]

  @type t :: %__MODULE__{
          module: atom(),
          name: atom(),
          # the value here is defined by the individual directive
          value: any(),
          meta: Surface.AST.Meta.t()
        }
end

defmodule Surface.AST.Attribute do
  defstruct [:name, :type, :value, :meta]

  @type t :: %__MODULE__{
          type: atom(),
          name: atom(),
          value: list(Surface.AST.Text.t() | Surface.AST.AttributeExpr.t()),
          meta: Surface.AST.Meta.t()
        }
end

defmodule Surface.AST.AttributeExpr do
  defstruct [:original, :value, :meta]

  @type t :: %__MODULE__{
          # quoted
          value: any(),
          original: binary(),
          meta: Surface.AST.Meta.t()
        }
end

defmodule Surface.AST.Interpolation do
  defstruct [:value, :meta]

  @type t :: %__MODULE__{
          # quoted
          value: any(),
          meta: Surface.AST.Meta.t()
        }
end

defmodule Surface.AST.Slot do
  defstruct [:name, :props, :default, :meta]

  @type t :: %__MODULE__{
          name: binary(),
          meta: Surface.AST.Meta.t(),
          # quoted ?
          props: any(),
          default: list()
        }
end

defmodule Surface.AST.Text do
  defstruct [:value]

  @type t :: %__MODULE__{
          value: binary | boolean
        }
end

defmodule Surface.AST.Tag do
  defstruct [:element, :attributes, :directives, :children, :meta]

  @type t :: %__MODULE__{
          element: binary(),
          attributes: list(Surface.AST.Attribute.t()),
          directives: list(Surface.AST.Directive.t()),
          children: list(Surface.AST.t()),
          meta: Surface.AST.Meta.t()
        }
end

defmodule Surface.AST.Template do
  defstruct [:name, :children, :props, :meta]

  @type t :: %__MODULE__{
          name: atom(),
          children: list(Surface.AST.t()),
          # quoted?
          props: any(),
          meta: Surface.AST.Meta.t()
        }
end

defmodule Surface.AST.Error do
  defstruct [:message, :meta]

  @type t :: %__MODULE__{
          message: binary(),
          meta: Surface.HTML.Meta.t()
        }
end

defmodule Surface.AST.Component do
  defstruct [:module, :props, :directives, :templates, :meta]

  @type t :: %__MODULE__{
          module: atom(),
          props: list(Surface.AST.Attribute.t()),
          directives: list(Surface.AST.Directive.t()),
          templates: %{
            :default => list(Surface.AST.Template.t()),
            optional(atom()) => list(Surface.AST.Template.t())
          },
          meta: Surface.AST.Meta.t()
        }
end
