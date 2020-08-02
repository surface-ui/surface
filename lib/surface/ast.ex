defmodule Surface.AST do
  @type t ::
          Surface.AST.Text.t()
          | Surface.AST.Interpolation.t()
          | Surface.AST.Tag.t()
          | Surface.AST.Template.t()
          | Surface.AST.Slot.t()
          | Surface.AST.Conditional.t()
          | Surface.AST.Comprehension.t()
          | Surface.AST.Container.t()
          | Surface.AST.Component.t()
          | Surface.AST.Error.t()
end

defmodule Surface.AST.Container do
  @moduledoc """
  An AST node representing a container of other nodes. This does not
  have content itself, just contains children which have content, and
  directives that operate on the entirety of the children (i.e. for, if, debug)

  ## Properties
      * `:children` - children AST nodes
      * `:directives` - directives associated with this container
  """
  defstruct [:children, :directives]

  @type t :: %__MODULE__{
          children: list(Surface.AST.t()),
          directives: list(Surface.AST.Directive.t())
        }
end

defmodule Surface.AST.Meta do
  @moduledoc """
  A container for metadata about compilation.

  ## Properties
      * `:line` - the line from the source code where the parent was extracted
      * `:module` - the component module (e.g. `Surface.Components.LivePatch`)
      * `:node_alias` - the alias used inside the source code (e.g. `LivePatch`)
      * `:file` - the file from which the source was extracted
      * `:line_offset` - the line offset from the caller's line to the start of this source
      * `:caller` - a Macro.Env struct representing the caller
  """
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
  @moduledoc """
  An AST node representing a directive

  ## Properties
      * `:module` - the module which implements logic for this directive (e.g. `Surface.Directive.Let`)
      * `:name` - the name of the directive (e.g. `:let`)
      * `:value` - the code/configuration for this directive. typically a quoted expression
      * `:meta` - compilation meta data
  """
  defstruct [:module, :name, :value, :meta]

  @type t :: %__MODULE__{
          module: atom(),
          name: atom(),
          # the value here is defined by the individual directive
          value: any(),
          meta: Surface.AST.Meta.t()
        }
end

defmodule Surface.AST.Comprehension do
  @moduledoc """
  An AST node representing a for comprehension.binary()

  ## Properties
      * `:generator` - a quoted expression
      * `:children` - the children to collect over the generator
      * `:meta` - compilation meta data
  """
  defstruct [:generator, :children, :meta]

  @type t :: %__MODULE__{
          generator: any(),
          children: list(Surface.AST.t()),
          meta: Surface.AST.Meta.t()
        }
end

defmodule Surface.AST.Conditional do
  @moduledoc """
  An AST node representing a conditionally rendered block

  ## Properties
      * `:condition` - a quoted expression
      * `:children` - the children to insert into the dom if the condition evaluates truthy
      * `:meta` - compilation meta data
  """
  defstruct [:condition, :children, :meta]

  @type t :: %__MODULE__{
          condition: any(),
          children: list(Surface.AST.t()),
          meta: Surface.AST.Meta.t()
        }
end

defmodule Surface.AST.Attribute do
  @moduledoc """
  An AST node representing an attribute or property

  ## Properties
      * `:type` - an atom representing the type of attribute. See Surface.API for the list of supported types
      * `:name` - the name of the attribute (e.g. `:class`)
      * `:value` - a list of nodes that can be concatenated to form the value for this attribute. Potentially contains dynamic data
      * `:meta` - compilation meta data
  """
  defstruct [:name, :type, :value, :meta]

  @type t :: %__MODULE__{
          type: atom(),
          name: atom(),
          value: list(Surface.AST.Text.t() | Surface.AST.AttributeExpr.t()),
          meta: Surface.AST.Meta.t()
        }
end

defmodule Surface.AST.DynamicAttribute do
  @moduledoc """
  An AST node representing a dynamic attribute (or attributes).

  ## Properties
      * `:expr` - an expression which will generate a keyword list of attributes and value tuples of the form {type, value}
      * `:meta` - compilation meta data
  """
  defstruct [:name, :expr, :meta]

  @type t :: %__MODULE__{
          expr: Surface.AST.AttributeExpr.t(),
          meta: Surface.AST.Meta.t()
        }
end

defmodule Surface.AST.AttributeExpr do
  @moduledoc """
  An AST node representing an attribute expression (i.e. a dynamic value for an attribute, directive, or property)

  ## Properties
      * `:original` - the original text, useful for debugging and error messages
      * `:value` - a quoted expression
      * `:meta` - compilation meta data
  """
  defstruct [:original, :value, :meta]

  @type t :: %__MODULE__{
          # quoted
          value: any(),
          original: binary(),
          meta: Surface.AST.Meta.t()
        }
end

defmodule Surface.AST.Interpolation do
  @moduledoc """
  An AST node representing interpolation within a node

  ## Properties
      * `:original` - the original text, useful for debugging and error messages
      * `:value` - a quoted expression
      * `:meta` - compilation meta data
  """
  defstruct [:original, :value, :meta]

  @type t :: %__MODULE__{
          original: binary(),
          # quoted
          value: any(),
          meta: Surface.AST.Meta.t()
        }
end

defmodule Surface.AST.Slot do
  @moduledoc """
  An AST node representing a <slot /> element

  ## Properties
      * `:name` - the slot name
      * `:default` - a list of AST nodes representing the default content for this slot
      * `:props` - either an atom or a quoted expression representing bindings for this slot
      * `:meta` - compilation meta data
  """
  defstruct [:name, :props, :default, :meta]

  @type t :: %__MODULE__{
          name: binary(),
          meta: Surface.AST.Meta.t(),
          # quoted ?
          props: Surface.AST.Directive.t(),
          default: list()
        }
end

defmodule Surface.AST.Text do
  @moduledoc """
  An AST node representing static text

  ## Properties
      * `:value` - the text
  """
  defstruct [:value]

  @type t :: %__MODULE__{
          value: binary | boolean
        }
end

defmodule Surface.AST.Tag do
  @moduledoc """
  An AST node representing a standard HTML tag

  ## Properties
      * `:element` - the element name
      * `:attributes` - the attributes for this tag
      * `:directives` - any directives to be applied to this tag
      * `:children` - the tag children
      * `:meta` - compilation meta data
  """
  defstruct [:element, :attributes, :directives, :children, :meta]

  @type t :: %__MODULE__{
          element: binary(),
          attributes: list(Surface.AST.Attribute.t() | Surface.AST.DynamicAttribute.t()),
          directives: list(Surface.AST.Directive.t()),
          children: list(Surface.AST.t()),
          meta: Surface.AST.Meta.t()
        }
end

defmodule Surface.AST.VoidTag do
  @moduledoc """
  An AST node representing a void (empty) HTML tag

  ## Properties
      * `:element` - the element name
      * `:attributes` - the attributes for this tag
      * `:directives` - any directives to be applied to this tag
      * `:meta` - compilation meta data
  """
  defstruct [:element, :attributes, :directives, :meta]

  @type t :: %__MODULE__{
          element: binary(),
          attributes: list(Surface.AST.Attribute.t() | Surface.AST.DynamicAttribute.t()),
          directives: list(Surface.AST.Directive.t()),
          meta: Surface.AST.Meta.t()
        }
end

defmodule Surface.AST.Template do
  @moduledoc """
  An AST node representing a <template> element. This is used to provide content for slots

  ## Properties
      * `:name` - the template name
      * `:props` - the props expression for this template
      * `:children` - the template children
      * `:meta` - compilation meta data
  """
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
  @moduledoc """
  An AST node representing an error. This will be rendered as an html element.

  ## Properties
      * `:message` - the error message
      * `:meta` - compilation meta data
  """
  defstruct [:message, :meta]

  @type t :: %__MODULE__{
          message: binary(),
          meta: Surface.HTML.Meta.t()
        }
end

defmodule Surface.AST.Component do
  @moduledoc """
  An AST node representing a standard HTML tag

  ## Properties
      * `:module` - the component module
      * `:type` - the type of component (i.e. Surface.LiveComponent vs Surface.LiveView)
      * `:props` - the props for this component
      * `:directives` - any directives to be applied to this tag
      * `:children` - the tag children
      * `:meta` - compilation meta data
  """
  defstruct [:module, :type, :props, :directives, :templates, :meta]

  @type t :: %__MODULE__{
          module: module(),
          type: module(),
          props: list(Surface.AST.Attribute.t()),
          directives: list(Surface.AST.Directive.t()),
          templates: %{
            :default => list(Surface.AST.Template.t()),
            optional(atom()) => list(Surface.AST.Template.t())
          },
          meta: Surface.AST.Meta.t()
        }
end
