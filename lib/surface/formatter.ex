defmodule Surface.Formatter do
  @moduledoc "Functions for formatting Surface code snippets." && false

  alias Surface.Formatter.Phases

  @typedoc """
  Options that can be passed to `Surface.Formatter.format_string!/2`.

    - `:line_length` - Maximum line length before wrapping opening tags
    - `:indent` - Starting indentation depth depending on the context of the ~F sigil
  """
  @type option :: {:line_length, integer} | {:indent, integer}

  @typedoc """
  The name of an HTML/Surface tag, such as `div`, `ListItem`, or `#Markdown`.
  """
  @type tag :: String.t()

  @typedoc "The value of a parsed HTML/Component attribute."
  @type attribute_value ::
          integer
          | boolean
          | String.t()
          | {:attribute_expr, interpolated_expression :: String.t(), term}
          | [String.t()]

  @typedoc "A parsed HTML/Component attribute name and value."
  @type attribute :: {name :: String.t(), attribute_value, term}

  @typedoc "A node output by `Surface.Compiler.Parser.parse`."
  @type surface_node ::
          String.t()
          | {:interpolation, String.t(), map}
          | {tag, list(attribute), list(surface_node), map}

  @typedoc """
  Whitespace nodes that can be rendered by `Surface.Formatter.Render.node/2`.

  The Surface parser does not return these, but formatter phases introduce these nodes
  in preparation for rendering.

  - `:newline` adds a newline (`\\n`) character
  - `:space` adds a space (` `) character
  - `:indent` adds spaces at the appropriate indentation amount
  - `:indent_one_less` adds spaces at 1 indentation level removed (used for closing tags)
  """
  @type whitespace ::
          :newline
          | :space
          | :indent
          | :indent_one_less

  @typedoc """
  A node that will ultimately be sent to `Surface.Formatter.Render.node/2` for rendering.

  The output of `Surface.Compiler.Parser.parse` is ran through the various formatting
  phases, which ultimately output a tree of this type.
  """
  @type formatter_node :: surface_node | whitespace

  @doc """
  Formats the given Surface code string. (Typically the contents of an `~F`
  sigil or `.sface` file.)

  In short:

    - HTML/Surface elements are indented to the right of their parents.
    - Attributes are split on multiple lines if the line is too long; otherwise on the same line.
    - Elixir code snippets (inside `{ }`) are ran through the Elixir code formatter.
    - Lack of whitespace is preserved, so that intended behaviors are not removed.
      (For example, `<span>Foo bar baz</span>` will not have newlines or spaces added.)

  Below the **Options** section is a non-exhaustive list of behaviors of the formatter.

  # Options

    * `:line_length` - the line length to aim for when formatting
    the document. Defaults to 98. As with the Elixir formatter,
    this value is used as reference but is not always enforced
    depending on the context.

  # Indentation

  The formatter ensures that children are indented one tab (two spaces) in from
  their parent.

  # Whitespace

  ## Whitespace that exists

  As in regular HTML, any string of continuous whitespace is considered
  equivalent to any other string of continuous whitespace. There are four
  exceptions:

  1. Macro components (with names starting with `#`, such as `<#Markdown>`)
  2. `<pre>` tags
  3. `<code>` tags
  4. `<script>` tags

  The contents of those tags are considered whitespace-sensitive, and developers
  should sanity check after running the formatter.

  ## Whitespace that doesn't exist (Lack of whitespace)

  As is sometimes the case in HTML, _lack_ of whitespace is considered
  significant. Instead of attempting to determine which contexts matter, the
  formatter consistently retains lack of whitespace. This means that the
  following

  ```html
  <div><p>Hello</p></div>
  ```

  will not be changed. However, the following

  ```html
  <div> <p> Hello </p> </div>
  ```

  will be formatted as

  ```html
  <div>
    <p>
      Hello
    </p>
  </div>
  ```

  because of the whitespace on either side of each tag.

  To be clear, this example

  ```html
  <div> <p>Hello</p> </div>
  ```

  will be formatted as

  ```html
  <div>
    <p>Hello</p>
  </div>
  ```

  because of the lack of whitespace in between the opening and closing `<p>` tags
  and their child content.

  ## Splitting children onto separate lines

  In certain scenarios, the formatter will move nodes to their own line:

  (Below, "element" means an HTML element or a Surface component.)

  1. If an element contains other elements as children, it will be surrounded by newlines.
  2. If there is a space after an opening tag or before a closing tag, it is converted to a newline.
  3. If a closing tag is put on its own line, the formatter ensures there's a newline before the next sibling node.

  Since SurfaceFormatter doesn't know if a component represents an inline or block element,
  it does not currently make distinctions between elements that should or should not be
  moved onto their own lines, other than the above rules.

  This allows inline elements to be placed among text without splitting them onto their own lines:

  ```html
  The <b>Dialog</b> is a stateless component. All event handlers
  had to be defined in the parent <b>LiveView</b>.
  ```

  ## Newline characters

  The formatter will not add extra newlines unprompted beyond moving nodes onto
  their own line.  However, if the input code has extra newlines, the formatter
  will retain them but will collapse more than one extra newline into a single
  one.

  This means that

  ```html
  <p>Hello</p>





  <p>Goodbye</p>
  ```

  will be formatted as

  ```html
  <p>Hello</p>

  <p>Goodbye</p>
  ```

  # HTML attributes and component props

  HTML attributes such as `class` in `<p class="container">` and component
  props such as `name` in `<Person name="Samantha">` are formatted to make use
  of Surface features.

  ## Inline literals

  String literals are placed after the `=` without any interpolation brackets (`{ }`). This means that

  ```html
  <Component foo={"hello"} />
  ```

  will be formatted as

  ```html
  <Component foo="hello" />
  ```

  Also, `true` boolean literals are formatted using the Surface shorthand
  whereby you can simply write the name of the attribute and it is passed in as
  `true`. For example,

  ```html
  <Component secure={true} />
  ```

  and

  ```html
  <Component secure=true />
  ```

  will both be formatted as

  ```html
  <Component secure />
  ```

  ## Interpolation (`{ }` brackets)

  Attributes that interpolate Elixir code with `{ }` brackets are ran through
  the Elixir code formatter.

  This means that:

    - `<Foo num={123456} />` becomes `<Foo num={123_456} />`
    - `list={[1,2,3]}` becomes `list={[1, 2, 3]}`
    - `things={%{  one: "1",   two: "2"}}` becomes `things={%{one: "1", two: "2"}}`

  Sometimes the Elixir code formatter will add line breaks in the formatted
  expression. In that case, SurfaceFormatter will ensure indentation lines up. If
  there is a single attribute, it will keep the attribute on the same line as the
  tag name, for example:

  ```html
  <Component list={[
    {"foo", foo},
    {"bar", bar}
  ]} />
  ```

  However, if there are multiple attributes it will put them on separate lines:

  ```html
  <Child
    list={[
      {"foo", foo},
      {"bar", bar}
    ]}
    int={123}
  />
  ```

  ## Whitespace in string attributes

  ### Code semantics must be maintained

  It's critical that a code formatter never change the semantics of the code
  it modifies.  In other words, the behavior of a program should never change
  due to a code formatter.

  The **Whitespace** section above outlines how `SurfaceFormatter` preserves
  code semantics by refusing to modify contents of `<script>`, `<code>` and
  `<pre>` tags as well as macro components. And for the same reason, the
  formatter does not introduce whitespace between HTML tags when there is none.

  ### Code semantics in string attributes

  This principle is also relevant to string attributes, such as:

  ```html
  <MyComponent string_prop="  string  with  whitespace  " />
  ```

  `SurfaceFormatter` cannot reliably guess whether application behavior will be
  changed by formatting the contents of a string. For example, consider a
  component with the following interface:

  ```html
  <List items="
  apples (fuji)
  oranges (navel)
  bell peppers (green)
  " />
  ```

  The component internally splits on newline characters and outputs the following HTML:

  ```html
  <ul>
    <li>apples (fuji)</li>
    <li>oranges (navel)</li>
    <li>bell peppers (green)</li>
  </ul>
  ```

  If `SurfaceFormatter` assumes it is safe to modify whitespace in string
  attributes, then the Surface code would likely change to this:

  ```html
  <List items="apples (fuji) oranges (navel) bell peppers (green)" />
  ```

  Which would output the following HTML:

  ```html
  <ul>
    <li>apples (fuji) oranges (navel) bell peppers (green)</li>
  </ul>
  ```

  Notice that the behavior of the application would have changed simply by
  running the formatter. It is for this reason that `SurfaceFormatter`
  always retains precisely the same whitespace in attribute strings,
  including both space and newline characters.

  ## Wrapping attributes on separate lines

  In the **Interpolation (`{ }` brackets)** section we noted that attributes
  will each be put on their own line if there is more than one attribute and at
  least one contains a newline after being formatted by the Elixir code
  formatter.

  There is another scenario where attributes will each be given their own line:
  **any time the opening tag would exceed `line_length` if put on one line**.
  This value is provided in `.formatter.exs` and defaults to 98.

  The formatter indents attributes one tab in from the start of the opening tag
  for readability:

  ```html
  <div
    class="very long class value that causes this to exceed the established line length"
    aria-role="button"
  >
  ```

  If you desire to have a separate line length for `mix format` and `mix surface.format`,
  provide `surface_line_length` in `.formatter.exs` and it will be given precedence
  when running `mix surface.format`. For example:

  ```elixir
  # .formatter.exs

  [
    surface_line_length: 120,
    import_deps: [...],
    # ...
  ]
  ```

  # Developer Responsibility

  As with all changes (for both `mix format` and `mix surface.format`) it's
  recommended that developers don't blindly run the formatter on an entire
  codebase and commit, but instead sanity check each file to ensure the results
  are desired.
  """
  @spec format_string!(String.t(), list(option)) :: String.t()
  def format_string!(string, opts \\ []) do
    trailing_newline =
      case Regex.run(~r/\n+\s*$/, string) do
        [match] -> match
        nil -> nil
      end

    parsed =
      string
      |> String.trim()
      |> Surface.Compiler.Parser.parse!(translator: Surface.Formatter.NodeTranslator)

    # Ensure the :indent and :trailing_newline options are set
    opts =
      opts
      |> Keyword.put_new(:indent, 0)
      |> Keyword.put(:trailing_newline, !is_nil(trailing_newline))

    [
      Phases.TagWhitespace,
      Phases.Newlines,
      Phases.SpacesToNewlines,
      Phases.Indent,
      Phases.FinalNewline,
      Phases.BlockExceptions,
      Phases.Render
    ]
    |> Enum.reduce(parsed, fn phase, nodes ->
      phase.run(nodes, opts)
    end)
  end

  @doc """
  Returns true if the argument is an element (HTML element or surface
  component), false otherwise.
  """
  @spec is_element?(surface_node) :: boolean
  def is_element?({_, _, _, _}), do: true
  def is_element?(_), do: false

  @doc """
  Given a tag, return whether to render the contents verbatim instead of formatting them.
  Specifically, don't modify contents of macro components or <pre> and <code> tags.
  """
  @spec render_contents_verbatim?(tag) :: boolean
  def render_contents_verbatim?("#slot"), do: false
  def render_contents_verbatim?("#" <> _), do: true
  def render_contents_verbatim?("pre"), do: true
  def render_contents_verbatim?("code"), do: true
  def render_contents_verbatim?("script"), do: true
  def render_contents_verbatim?(tag) when is_binary(tag), do: false
end
