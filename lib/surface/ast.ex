defmodule Surface.AST do
  @type t ::
          Surface.AST.Literal.t()
          | Surface.AST.Interpolation.t()
          | Surface.AST.Expr.t()
          | Surface.AST.Tag.t()
          | Surface.AST.VoidTag.t()
          | Surface.AST.Template.t()
          | Surface.AST.Slot.t()
          | Surface.AST.If.t()
          | Surface.AST.For.t()
          | Surface.AST.Container.t()
          | Surface.AST.Component.t()
          | Surface.AST.MacroComponent.t()
          | Surface.AST.SlotableComponent.t()
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
      * `:meta` - compile meta
      * `:debug` - keyword list indicating when debug information should be printed during compilation
  """
  defstruct [:children, :meta, debug: [], directives: []]

  @type t :: %__MODULE__{
          children: list(Surface.AST.t()),
          debug: list(atom()),
          meta: Surface.AST.Meta.t(),
          directives: list(Surface.AST.Directive.t())
        }
end

defmodule Surface.AST.Block do
  @moduledoc """
  An AST node representing a generic block.

  ## Properties
      * `:name` - name of the block
      * `:expression` - the expression passed to block
      * `:sub_blocks` - a list containing each sub-block's {name, children_ast}
      * `:meta` - compile meta
      * `:debug` - keyword list indicating when debug information should be printed during compilation
  """
  defstruct [:name, :expression, :sub_blocks, :meta, debug: []]

  @type t :: %__MODULE__{
          name: binary(),
          expression: Surface.AST.AttributeExpr.t(),
          sub_blocks: [{:default | binary(), Surface.AST.t()}],
          debug: list(atom()),
          meta: Surface.AST.Meta.t()
        }
end

defmodule Surface.AST.SubBlock do
  @moduledoc """
  An AST node representing a generic sub-block.

  ## Properties
      * `:name` - name of the block
      * `:expression` - the expression passed to block
      * `:children` - children AST nodes
      * `:meta` - compile meta
      * `:debug` - keyword list indicating when debug information should be printed during compilation
  """
  defstruct [:name, :expression, :children, :meta, debug: []]

  @type t :: %__MODULE__{
          name: binary(),
          expression: Surface.AST.AttributeExpr.t(),
          children: list(Surface.AST.t()),
          debug: list(atom()),
          meta: Surface.AST.Meta.t()
        }
end

defmodule Surface.AST.Expr do
  @moduledoc """
  An AST node representing an expression which does not resolve to a value printed out to the final DOM.

  ## Properties
      * `:value` - a quoted expression
      * `:meta` - compile meta
      * `:directives` - directives associated with this expression node
  """
  defstruct [:value, :meta, directives: []]

  @type t :: %__MODULE__{
          # quoted expression
          value: any(),
          directives: list(Surface.AST.Directive.t()),
          meta: Surface.AST.Meta.t()
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
      * `:caller` - a Macro.Env struct representing the caller
  """
  @derive {Inspect, only: [:line, :column, :module, :node_alias, :file, :checks]}
  defstruct [:line, :column, :module, :node_alias, :file, :caller, :checks]

  @type t :: %__MODULE__{
          line: non_neg_integer(),
          column: non_neg_integer(),
          module: atom(),
          node_alias: binary() | nil,
          caller: Macro.Env.t(),
          file: binary(),
          checks: Keyword.t(boolean())
        }

  def quoted_caller_cid(meta) do
    cond do
      Module.open?(meta.caller.module) and
          Module.get_attribute(meta.caller.module, :component_type) == Surface.LiveComponent ->
        quote generated: true do
          @myself
        end

      true ->
        nil
    end
  end
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
          value: Surface.AST.AttributeExpr.t() | Surface.AST.Literal.t() | nil,
          meta: Surface.AST.Meta.t()
        }
end

defmodule Surface.AST.For do
  @moduledoc """
  An AST node representing a for comprehension.

  ## Properties
      * `:generator` - a quoted expression
      * `:children` - the children to collect over the generator
      * `:meta` - compilation meta data
      * `:debug` - keyword list indicating when debug information should be printed during compilation
      * `:directives` - directives associated with this node
  """
  defstruct [:generator, :children, :meta, else: [], debug: [], directives: []]

  @type t :: %__MODULE__{
          generator: any(),
          debug: list(atom()),
          directives: list(Surface.AST.Directive.t()),
          children: list(Surface.AST.t()),
          meta: Surface.AST.Meta.t()
        }
end

defmodule Surface.AST.If do
  @moduledoc """
  An AST node representing an if/else expression

  ## Properties
      * `:condition` - a quoted expression
      * `:children` - the children to insert into the dom if the condition evaluates truthy
      * `:else` - the children to insert into the dom if the condition evaluates falsy
      * `:meta` - compilation meta data
      * `:debug` - keyword list indicating when debug information should be printed during compilation
      * `:directives` - directives associated with this node
  """
  defstruct [:condition, :children, :meta, else: [], debug: [], directives: []]

  @type t :: %__MODULE__{
          condition: Surface.AST.AttributeExpr.t(),
          debug: list(atom()),
          directives: list(Surface.AST.Directive.t()),
          children: list(Surface.AST.t()),
          else: list(Surface.AST.t()),
          meta: Surface.AST.Meta.t()
        }
end

defmodule Surface.AST.Attribute do
  @moduledoc """
  An AST node representing an attribute or property

  ## Properties
      * `:type` - an atom representing the type of attribute. See Surface.API for the list of supported types
      * `:type_opts` - a keyword list of options for the type
      * `:name` - the name of the attribute (e.g. `:class`)
      * `:value` - a list of nodes that can be concatenated to form the value for this attribute. Potentially contains dynamic data
      * `:meta` - compilation meta data
  """
  defstruct [:name, :type, :type_opts, :value, :meta]

  @type t :: %__MODULE__{
          type: atom(),
          type_opts: keyword(),
          name: atom(),
          value: Surface.AST.Literal.t() | Surface.AST.AttributeExpr.t(),
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
      * `:directives` - directives associated with this interpolation
  """
  defstruct [:original, :value, :meta, directives: []]

  @type t :: %__MODULE__{
          original: binary(),
          # quoted
          value: any(),
          directives: list(Surface.AST.Directive.t()),
          meta: Surface.AST.Meta.t()
        }
end

defmodule Surface.AST.Slot do
  @moduledoc """
  An AST node representing a <#slot /> element

  ## Properties
      * `:name` - the slot name
      * `:index` - the index of the slotable entry assigned to this slot
      * `:default` - a list of AST nodes representing the default content for this slot
      * `:props` - either an atom or a quoted expression representing bindings for this slot
      * `:meta` - compilation meta data
      * `:directives` - directives associated with this slot
  """
  defstruct [:name, :index, :props, :default, :meta, directives: []]

  @type t :: %__MODULE__{
          name: binary(),
          index: any(),
          directives: list(Surface.AST.Directive.t()),
          meta: Surface.AST.Meta.t(),
          # quoted ?
          props: list(Keyword.t(any())),
          default: list(Surface.AST.t())
        }
end

# TODO differentiate between raw HTML and plain text ?
defmodule Surface.AST.Literal do
  @moduledoc """
  An AST node representing a literal value

  ## Properties
      * `:value` - the value
      * `:directives` - directives associated with this literal value
  """
  defstruct [:value, directives: []]

  @type t :: %__MODULE__{
          directives: list(Surface.AST.Directive.t()),
          value: binary | boolean | integer | atom
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
      * `:debug` - keyword list indicating when debug information should be printed during compilation
  """
  defstruct [:element, :attributes, :children, :meta, debug: [], directives: []]

  @type t :: %__MODULE__{
          element: binary(),
          debug: list(atom()),
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
      * `:debug` - keyword list indicating when debug information should be printed during compilation
  """
  defstruct [:element, :attributes, :meta, debug: [], directives: []]

  @type t :: %__MODULE__{
          element: binary(),
          debug: list(atom()),
          attributes: list(Surface.AST.Attribute.t() | Surface.AST.DynamicAttribute.t()),
          directives: list(Surface.AST.Directive.t()),
          meta: Surface.AST.Meta.t()
        }
end

defmodule Surface.AST.Template do
  @moduledoc """
  An AST node representing a <#template> element. This is used to provide content for slots

  ## Properties
      * `:name` - the template name
      * `:let` - the bindings for this template
      * `:children` - the template children
      * `:meta` - compilation meta data
      * `:debug` - keyword list indicating when debug information should be printed during compilation
      * `:directives` - directives associated with this template
  """
  defstruct [:name, :children, :let, :meta, directives: []]

  @type t :: %__MODULE__{
          name: atom(),
          children: list(Surface.AST.t()),
          directives: list(Surface.AST.Directive.t()),
          # quoted?
          let: list(Keyword.t(atom())),
          meta: Surface.AST.Meta.t()
        }
end

defmodule Surface.AST.Error do
  @moduledoc """
  An AST node representing an error. This will be rendered as an html element.

  ## Properties
      * `:message` - the error message
      * `:meta` - compilation meta data
      * `:directives` - directives associated with this error node
  """
  defstruct [:message, :meta, directives: []]

  @type t :: %__MODULE__{
          message: binary(),
          directives: list(Surface.AST.Directive.t()),
          meta: Surface.AST.Meta.t()
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
      * `:debug` - keyword list indicating when debug information should be printed during compilation
  """
  defstruct [:module, :type, :props, :dynamic_props, :templates, :meta, debug: [], directives: []]

  @type t :: %__MODULE__{
          module: module(),
          debug: list(atom()),
          type: module(),
          props: list(Surface.AST.Attribute.t()),
          dynamic_props: Surface.AST.DynamicAttribute.t(),
          directives: list(Surface.AST.Directive.t()),
          templates: %{
            :default => list(Surface.AST.Template.t() | Surface.AST.SlotableComponent.t()),
            optional(atom()) => list(Surface.AST.Template.t() | Surface.AST.SlotableComponent.t())
          },
          meta: Surface.AST.Meta.t()
        }
end

defmodule Surface.AST.MacroComponent do
  @moduledoc """
  An AST node representing a macro component

  ## Properties
      * `:module` - the component module
      * `:attributes` - the specified attributes
      * `:directives` - any directives to be applied to this macro
      * `:body` - the macro body
      * `:meta` - compilation meta data
      * `:debug` - keyword list indicating when debug information should be printed during compilation
  """
  defstruct [:module, :name, :attributes, :body, :meta, debug: [], directives: []]

  @type t :: %__MODULE__{
          module: module(),
          debug: list(atom()),
          name: binary(),
          attributes: list(Surface.AST.Attribute.t()),
          directives: list(Surface.AST.Directive.t()),
          body: iodata(),
          meta: Surface.AST.Meta.t()
        }
end

defmodule Surface.AST.SlotableComponent do
  @moduledoc """
  An AST node representing a standard HTML tag

  ## Properties
      * `:module` - the component module
      * `:type` - the type of component (i.e. Surface.LiveComponent vs Surface.Component)
      * `:slot` - the name of the slot that this component is for
      * `:let` - the bindings for this template
      * `:props` - the props for this component
      * `:directives` - any directives to be applied to this tag
      * `:children` - the tag children
      * `:meta` - compilation meta data
      * `:debug` - keyword list indicating when debug information should be printed during compilation
  """
  defstruct [
    :module,
    :slot,
    :type,
    :let,
    :props,
    :dynamic_props,
    :templates,
    :meta,
    debug: [],
    directives: []
  ]

  @type t :: %__MODULE__{
          module: module(),
          debug: list(atom()),
          type: module(),
          slot: atom(),
          let: list(Keyword.t(atom())),
          props: list(Surface.AST.Attribute.t()),
          dynamic_props: Surface.AST.DynamicAttribute.t(),
          directives: list(Surface.AST.Directive.t()),
          templates: %{
            :default => list(Surface.AST.Template.t()),
            optional(atom()) => list(Surface.AST.Template.t())
          },
          meta: Surface.AST.Meta.t()
        }
end
