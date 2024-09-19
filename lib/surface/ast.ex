defmodule Surface.AST.Container do
  @moduledoc """
  An AST node representing a container of other nodes. This does not
  have content itself, just contains children which have content, and
  directives that operate on the entirety of the children (i.e. for, if, debug)

  ## Properties
      * `:children` - children AST nodes
      * `:attributes` - the specified attributes
      * `:directives` - directives associated with this container
      * `:meta` - compile meta
      * `:debug` - keyword list indicating when debug information should be printed during compilation
  """
  defstruct [:children, :meta, debug: [], attributes: [], directives: []]

  @type t :: %__MODULE__{
          children: list(Surface.AST.t()),
          debug: list(atom()),
          meta: Surface.AST.Meta.t(),
          attributes: list(Surface.AST.Attribute.t()),
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
          sub_blocks: list(Surface.AST.SubBlock.t()),
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
          name: :default | binary(),
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
      * `:constant?` - true if the expression can be evaluated at compile time
      * `:meta` - compile meta
      * `:directives` - directives associated with this expression node
  """
  defstruct [:value, :meta, constant?: false, directives: []]

  @type t :: %__MODULE__{
          # quoted expression
          value: any(),
          constant?: boolean(),
          directives: list(Surface.AST.Directive.t()),
          meta: Surface.AST.Meta.t()
        }
end

defmodule Surface.AST.Meta do
  @moduledoc """
  A container for metadata about compilation.

  ## Properties
      * `:line` - the line from the source code where the parent was extracted
      * `:column` - the column from the source code where the parent was extracted
      * `:module` - the component module (e.g. `Surface.Components.LivePatch`)
      * `:node_alias` - the alias used inside the source code (e.g. `LivePatch`)
      * `:file` - the file from which the source was extracted
      * `:caller` - a Macro.Env struct representing the caller
      * `:style` - the style info of the component, if any
      * `:caller_spec` - the specs of the caller component
  """

  alias Surface.Compiler.Helpers

  @derive {Inspect, only: [:line, :column, :module, :node_alias, :file, :checks]}
  defstruct [
    :line,
    :column,
    :module,
    :node_alias,
    :file,
    :caller,
    :checks,
    :style,
    :caller_spec
  ]

  @type t :: %__MODULE__{
          line: non_neg_integer(),
          column: non_neg_integer(),
          module: atom(),
          node_alias: binary() | nil,
          caller: Macro.Env.t(),
          file: binary(),
          checks: Keyword.t(boolean()),
          caller_spec: struct(),
          style:
            %{
              scope_id: binary(),
              css: binary(),
              selectors: [binary()],
              vars: %{(var :: binary()) => expr :: binary()}
            }
            | nil
        }

  @doc false
  def quoted_caller_context(meta) do
    quoted_cid =
      if Helpers.is_stateful_component(meta.caller.module) and meta.caller.function == {:render, 1} do
        quote do: @myself
      else
        nil
      end

    quote do
      %{
        cid: unquote(quoted_cid),
        file: unquote(meta.file),
        line: unquote(meta.line),
        module: unquote(meta.caller.module)
      }
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
      * `:root` - true if the attribute was defined using root notation `{ ... }`. Root attributes won't have `name`.
      * `:value` - a list of nodes that can be concatenated to form the value for this attribute. Potentially contains dynamic data
      * `:meta` - compilation meta data
  """
  defstruct [:name, :root, :type, :type_opts, :value, :meta]

  @type t :: %__MODULE__{
          type: atom() | nil,
          type_opts: keyword() | nil,
          name: atom() | nil,
          root: boolean() | nil,
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
      * `:constant?` - true if the expression can be evaluated at compile time
      * `:meta` - compilation meta data
  """
  defstruct [:original, :value, :meta, constant?: false]

  @type t :: %__MODULE__{
          # quoted
          value: any(),
          original: binary(),
          constant?: boolean(),
          meta: Surface.AST.Meta.t()
        }

  def new(expr, original, meta) do
    %__MODULE__{
      value: expr,
      original: original,
      constant?: constant?(expr),
      meta: meta
    }
  end

  defp constant?(
         {{:., _, [{:__aliases__, _, [:Surface, :TypeHandler]}, :expr_to_value!]}, _,
          [_type, _name, clauses, opts, _module, _original, ctx]}
       ) do
    Macro.quoted_literal?(clauses) and Macro.quoted_literal?(opts) and Macro.quoted_literal?(ctx)
  end

  defp constant?(expr) do
    Macro.quoted_literal?(expr)
  end
end

defmodule Surface.AST.Interpolation do
  @moduledoc """
  An AST node representing interpolation within a node

  ## Properties
      * `:original` - the original text, useful for debugging and error messages
      * `:value` - a quoted expression
      * `:constant?` - true if the expression can be evaluated at compile time
      * `:meta` - compilation meta data
      * `:directives` - directives associated with this interpolation
  """
  defstruct [:original, :value, :meta, constant?: false, directives: []]

  @type t :: %__MODULE__{
          original: binary(),
          # quoted
          value: any(),
          constant?: boolean(),
          directives: list(Surface.AST.Directive.t()),
          meta: Surface.AST.Meta.t()
        }
end

defmodule Surface.AST.Slot do
  @moduledoc """
  An AST node representing a <#slot /> tag

  ## Properties
      * `:name` - the slot name
      * `:for` - the slotable entry assigned for this slot
      * `:default` - a list of AST nodes representing the default content for this slot
      * `:arg` - quoted expression representing the argument for this slot
      * `:generator_value` - value from the `:generator_prop` property
      * `:context_put` - value from the `:generator_prop` property
      * `:meta` - compilation meta data
      * `:directives` - directives associated with this slot
  """
  defstruct [:name, :as, :for, :arg, :generator_value, :context_put, :default, :meta, directives: []]

  @type t :: %__MODULE__{
          name: binary(),
          as: atom(),
          for: any(),
          directives: list(Surface.AST.Directive.t()),
          meta: Surface.AST.Meta.t(),
          arg: Macro.t(),
          generator_value: any(),
          context_put: list(Surface.AST.AttributeExpr.t()),
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

defmodule Surface.AST.SlotEntry do
  @moduledoc """
  An AST node representing a <:slot> entry. This is used to provide content for slots

  ## Properties
      * `:name` - the slot entry name
      * `:props` - the props for slot entry tag
      * `:let` - the `:let` expression
      * `:children` - the slot entry children
      * `:meta` - compilation meta data
      * `:debug` - keyword list indicating when debug information should be printed during compilation
      * `:directives` - directives associated with this slot entry
  """
  defstruct [:name, :props, :children, :let, :meta, directives: []]

  @type t :: %__MODULE__{
          name: atom(),
          children: list(Surface.AST.t()),
          directives: list(Surface.AST.Directive.t()),
          props: list(Surface.AST.Attribute.t() | Surface.AST.DynamicAttribute.t()),
          let: Surface.AST.AttributeExpr.t() | nil,
          meta: Surface.AST.Meta.t()
        }
end

defmodule Surface.AST.Error do
  @moduledoc """
  An AST node representing an error. This will be rendered as an html element.

  ## Properties
      * `:message` - the error message
      * `:meta` - compilation meta data
      * `:attributes` - the specified attributes
      * `:directives` - directives associated with this error node
  """
  defstruct [:message, :meta, attributes: [], directives: []]

  @type t :: %__MODULE__{
          message: binary(),
          attributes: list(Surface.AST.Attribute.t()),
          directives: list(Surface.AST.Directive.t()),
          meta: Surface.AST.Meta.t()
        }
end

defmodule Surface.AST.Component do
  @moduledoc """
  An AST node representing a component

  ## Properties
      * `:module` - the component module
      * `:type` - the type of component (i.e. Surface.LiveComponent vs Surface.LiveView or :dynamic_live)
      * `:props` - the props for this component
      * `:directives` - any directives to be applied to this tag
      * `:children` - the tag children
      * `:meta` - compilation meta data
      * `:debug` - keyword list indicating when debug information should be printed during compilation
  """
  defstruct [:module, :type, :props, :dynamic_props, :slot_entries, :meta, debug: [], directives: []]

  @type t :: %__MODULE__{
          module: module() | Surface.AST.AttributeExpr.t(),
          debug: list(atom()),
          type: module() | :dynamic_live,
          props: list(Surface.AST.Attribute.t()),
          dynamic_props: Surface.AST.DynamicAttribute.t(),
          directives: list(Surface.AST.Directive.t()),
          slot_entries: %{
            :default => list(Surface.AST.SlotEntry.t() | Surface.AST.SlotableComponent.t()),
            optional(atom()) => list(Surface.AST.SlotEntry.t() | Surface.AST.SlotableComponent.t())
          },
          meta: Surface.AST.Meta.t()
        }
end

defmodule Surface.AST.FunctionComponent do
  @moduledoc """
  An AST node representing a function component

  ## Properties
      * `:module` - the component module
      * `:fun` - the render function
      * `:type` - the type of function (:local or :remote)
      * `:props` - the props for this component
      * `:directives` - any directives to be applied to this tag
      * `:children` - the tag children
      * `:meta` - compilation meta data
      * `:debug` - keyword list indicating when debug information should be printed during compilation
  """
  defstruct [:module, :fun, :type, :props, :dynamic_props, :slot_entries, :meta, debug: [], directives: []]

  @type t :: %__MODULE__{
          module: module() | Surface.AST.AttributeExpr.t(),
          fun: atom() | Surface.AST.AttributeExpr.t() | nil,
          debug: list(atom()),
          type: :local | :remote | :dynamic,
          props: list(Surface.AST.Attribute.t()),
          dynamic_props: Surface.AST.DynamicAttribute.t(),
          directives: list(Surface.AST.Directive.t()),
          slot_entries: %{
            :default => list(Surface.AST.SlotEntry.t() | Surface.AST.SlotableComponent.t()),
            optional(atom()) => list(Surface.AST.SlotEntry.t() | Surface.AST.SlotableComponent.t())
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
      * `:children` - the children after the macro is expanded
      * `:meta` - compilation meta data
      * `:debug` - keyword list indicating when debug information should be printed during compilation
  """
  defstruct [:module, :name, :attributes, :children, :meta, debug: [], directives: []]

  @type t :: %__MODULE__{
          module: module(),
          debug: list(atom()),
          name: binary(),
          attributes: list(Surface.AST.Attribute.t()),
          directives: list(Surface.AST.Directive.t()),
          children: list(Surface.AST.t()),
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
      * `:let` - the `:let` expression
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
    :slot_entries,
    :meta,
    debug: [],
    directives: []
  ]

  @type t :: %__MODULE__{
          module: module(),
          debug: list(atom()),
          type: module(),
          slot: atom(),
          let: Surface.AST.AttributeExpr.t() | nil,
          props: list(Surface.AST.Attribute.t()),
          dynamic_props: Surface.AST.DynamicAttribute.t(),
          directives: list(Surface.AST.Directive.t()),
          slot_entries: %{
            :default => list(Surface.AST.SlotEntry.t()),
            optional(atom()) => list(Surface.AST.SlotEntry.t())
          },
          meta: Surface.AST.Meta.t()
        }
end

defmodule Surface.AST do
  alias __MODULE__

  @type t ::
          AST.Literal.t()
          | AST.Interpolation.t()
          | AST.Expr.t()
          | AST.Tag.t()
          | AST.VoidTag.t()
          | AST.SlotEntry.t()
          | AST.Slot.t()
          | AST.If.t()
          | AST.For.t()
          | AST.Container.t()
          | AST.Component.t()
          | AST.FunctionComponent.t()
          | AST.MacroComponent.t()
          | AST.SlotableComponent.t()
          | AST.Error.t()

  def find_attribute_value(attributes, name) do
    Enum.find_value(attributes, fn
      %AST.Attribute{name: ^name, value: value} -> value
      _ -> nil
    end)
  end

  def has_attribute?(attributes, name) do
    Enum.any?(attributes, fn %{name: attr_name} -> attr_name == name end)
  end

  def pop_attributes_values_as_map(attributes, names) do
    initial = {Map.new(names, &{&1, nil}), []}

    {map, others} =
      Enum.reduce(attributes, initial, fn %AST.Attribute{name: name, value: value} = attr, {map, others} ->
        if name in names do
          {Map.put(map, name, value), others}
        else
          {map, [attr | others]}
        end
      end)

    {map, Enum.reverse(others)}
  end

  def pop_attributes_as_map(attributes, names) do
    initial = {Map.new(names, &{&1, nil}), []}

    {map, others} =
      Enum.reduce(attributes, initial, fn
        %AST.Attribute{name: name} = attr, {map, others} ->
          if name in names do
            {Map.put(map, name, attr), others}
          else
            {map, [attr | others]}
          end

        attr, {map, others} ->
          {map, [attr | others]}
      end)

    {map, Enum.reverse(others)}
  end
end
