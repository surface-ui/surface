defmodule Surface.FormatterTest do
  use ExUnit.Case

  alias Surface.Formatter

  def assert_formatter_outputs(input_code, expected_formatted_result, opts \\ []) do
    assert Formatter.format_string!(input_code, opts) == expected_formatted_result

    # demonstrate that the output can be parsed by the Surface parser
    Surface.Compiler.Parser.parse!(expected_formatted_result)
  end

  def assert_formatter_doesnt_change(code, opts \\ []) do
    assert_formatter_outputs(code, code, opts)
  end

  describe "[whitespace]" do
    test "children are indented 1 from parents" do
      assert_formatter_outputs(
        """
        <div>
        <ul>
        <li>
        <a>
        Hello
        </a>
        </li>
        </ul>
        </div>
        """,
        """
        <div>
          <ul>
            <li>
              <a>
                Hello
              </a>
            </li>
          </ul>
        </div>
        """
      )
    end

    test "empty inputs are not changed" do
      assert_formatter_doesnt_change("")

      assert_formatter_doesnt_change("""
      """)
    end

    test "single line inputs are not changed" do
      assert_formatter_doesnt_change("<div />")

      assert_formatter_doesnt_change("""
      <Component with="attribute" />
      """)
    end

    test "trailing whitespace is trimmed on single line inputs" do
      assert_formatter_outputs(~s{<div/>    }, ~s{<div />})
    end

    test "Contents of macro components are preserved" do
      assert_formatter_doesnt_change("""
      <#MacroComponent>
      * One
      * Two
      ** Three
      *** Four
              **** Five
        -- Once I caught a fish alive
      </#MacroComponent>
      """)

      assert_formatter_doesnt_change("""
      <#MacroComponent>
       * One
       * Two
       ** Three
       *** Four
               **** Five
         -- Once I caught a fish alive
      </#MacroComponent>
      """)
    end

    test "lack of whitespace is preserved" do
      assert_formatter_outputs(
        """
        <div>
        <dt>{ @tldr }/{ @question }</dt>
        <dd><#slot /></dd>
        </div>
        """,
        """
        <div>
          <dt>{@tldr}/{@question}</dt>
          <dd><#slot /></dd>
        </div>
        """
      )
    end

    test "generator attributes are formatted successfully" do
      assert_formatter_doesnt_change("""
      <div :for={item <- @items, item.state == :valid}>
      </div>
      """)
    end

    test "attributes wrap after 98 characters by default" do
      assert_formatter_doesnt_change("""
      <Component foo="..........." bar="..............." baz="............" qux="..................." />
      """)

      assert_formatter_outputs(
        """
        <Component foo="..........." bar="..............." baz="............" qux="...................." />
        """,
        """
        <Component
          foo="..........."
          bar="..............."
          baz="............"
          qux="...................."
        />
        """
      )
    end

    test "attribute wrapping can be configured by :line_length in opts" do
      assert_formatter_outputs(
        """
        <Foo bar="bar" baz="baz"/>
        """,
        """
        <Foo
          bar="bar"
          baz="baz"
        />
        """,
        line_length: 20
      )
    end

    test "a single attribute always begins on the same line as the opening tag" do
      # Wrap in another element to help test whether indentation is working properly

      assert_formatter_outputs(
        """
        <p>
        <Foo bio={%{age: 23, name: "John Jacob Jingleheimerschmidt", title: "Lead rockstar 10x ninja brogrammer", reports_to: "James Jacob Jingleheimerschmidt"}}/>
        </p>
        """,
        """
        <p>
          <Foo bio={%{
            age: 23,
            name: "John Jacob Jingleheimerschmidt",
            title: "Lead rockstar 10x ninja brogrammer",
            reports_to: "James Jacob Jingleheimerschmidt"
          }} />
        </p>
        """
      )

      assert_formatter_outputs(
        """
        <p>
          <Foo urls={["https://hexdocs.pm/elixir/DateTime.html#content", "https://hexdocs.pm/elixir/Exception.html#content"]}/>
        </p>
        """,
        """
        <p>
          <Foo urls={[
            "https://hexdocs.pm/elixir/DateTime.html#content",
            "https://hexdocs.pm/elixir/Exception.html#content"
          ]} />
        </p>
        """
      )

      assert_formatter_outputs(
        """
        <p>
        <Foo bar={baz: "BAZ", qux: "QUX", long: "LONG", longer: "LONGER", longest: "LONGEST", wrapping: "WRAPPING", next_line: "NEXT_LINE"} />
        </p>
        """,
        """
        <p>
          <Foo bar={
            baz: "BAZ",
            qux: "QUX",
            long: "LONG",
            longer: "LONGER",
            longest: "LONGEST",
            wrapping: "WRAPPING",
            next_line: "NEXT_LINE"
          } />
        </p>
        """
      )

      assert_formatter_outputs(
        """
        <p>
        <Foo bar="A really really really really really really long string that makes this line longer than the default 98 characters"/>
        </p>
        """,
        """
        <p>
          <Foo bar="A really really really really really really long string that makes this line longer than the default 98 characters" />
        </p>
        """
      )
    end

    test "(bugfix) a trailing expression does not get an extra newline added" do
      assert_formatter_doesnt_change("""
      <p>Foo</p><p>Bar</p>{baz}
      """)
    end

    test "Contents of <pre> and <code> tags aren't formatted" do
      # Note that the output looks pretty messy, but it's because
      # we're retaining 100% of the exact characters between the
      # <pre> and </pre> tags, etc.
      assert_formatter_outputs(
        """
        <p>
        <pre>
            Four
         One
                 Nine
        </pre> </p> <div> <code>Some code
        goes    here   </code> </div>
        """,
        """
        <p>
          <pre>
            Four
         One
                 Nine
        </pre>
        </p>
        <div>
          <code>Some code
        goes    here   </code>
        </div>
        """
      )
    end

    test "<pre>, <code>, <script>, and <#MacroComponent> tags can contain expressions or components, but the string portions are untouched" do
      # Note that the output looks pretty messy, but it's because
      # we're retaining 100% of the exact characters between the
      # <pre> and </pre> tags, etc.
      #
      # Also, note that the _opening_ tags are consistently at the same
      # indentation level because those tags are not inside a context
      # in which we render children verbatim. (In other words, there's
      # no risk of changing browser behavior.)
      assert_formatter_outputs(
        """
        <pre>
        {   @data   }
              <Component />
        </pre>
            <code>
          { @data }
          <Component />
            </code>


              <#MacroComponent> Foo {@bar} baz </#MacroComponent>

        <script type="application/javascript">
             foo();
           var bar="baz";
        </script>
        """,
        """
        <pre>
        {@data}
              <Component />
        </pre>
        <code>
          {@data}
          <Component />
            </code>

        <#MacroComponent> Foo {@bar} baz </#MacroComponent>

        <script type="application/javascript">
             foo();
           var bar="baz";
        </script>
        """
      )
    end

    test "HTML elements rendered in <pre>/<code>/<#MacroComponent> tags are left in their original state" do
      # Note that the <code> and <#Macro> components (which are too indented)
      # are brought all the way to the left side, but all of the whitespace
      # characters therein are left alone.
      assert_formatter_outputs(
        """
        <pre>
            <div>    <p>  Hello world  </p>  </div>
          </pre>

          <code>
              <div>    <p>  Hello world  </p>  </div>
            </code>

            <#Macro>
                <div>    <p>  Hello world  </p>  </div>
              </#Macro>
        """,
        """
        <pre>
            <div>    <p>  Hello world  </p>  </div>
          </pre>

        <code>
              <div>    <p>  Hello world  </p>  </div>
            </code>

        <#Macro>
                <div>    <p>  Hello world  </p>  </div>
              </#Macro>
        """
      )
    end

    test "Attributes are lines up properly when split onto newlines with a multi-line attribute" do
      assert_formatter_outputs(
        """
        <Parent>
          <Child
            first={123}
            second={[
                    {"foo", application.description},
                    {"baz", application.product_owner}
                  ]}
          />
        </Parent>
        """,
        """
        <Parent>
          <Child
            first={123}
            second={[
              {"foo", application.description},
              {"baz", application.product_owner}
            ]}
          />
        </Parent>
        """
      )
    end

    test "If any attribute is formatted with a newline, attributes are split onto separate lines" do
      # This is because multiple of them may have newlines, and it could result in odd formatting such as:
      #
      # <Foo bar=1 baz={{[
      #   "bazz",
      #   "bazz",
      #   "bazz"
      # ]}} qux=false />
      #
      # The attributes aren't the easiest to read in that case, and we're making the choice not
      # to open the can of worms of potentially re-ordering attributes, because that introduces
      # plenty of complexity and might not be desired by users.
      assert_formatter_outputs(
        """
        <Parent>
          <Child
            first={ 123 }
            second={[
                    {"foo", foo},
                    {"bar", bar}
                  ]}
          />
        </Parent>
        """,
        """
        <Parent>
          <Child
            first={123}
            second={[
              {"foo", foo},
              {"bar", bar}
            ]}
          />
        </Parent>
        """
      )

      assert_formatter_outputs(
        """
        <Parent>
          <Child first={[
          {"foo", foo}, {"bar", bar}
          ]} second={ 123 } />
        </Parent>
        """,
        """
        <Parent>
          <Child
            first={[
              {"foo", foo},
              {"bar", bar}
            ]}
            second={123}
          />
        </Parent>
        """
      )
    end

    test "tags without children are collapsed if there is no whitespace between them" do
      assert_formatter_outputs(
        """
        <Foo></Foo>
        """,
        """
        <Foo />
        """
      )

      # Should these be collapsed?
      assert_formatter_doesnt_change("""
      <Foo> </Foo>
      """)
    end

    test "lists with invisible brackets in attribute expressions are formatted" do
      assert_formatter_outputs(
        ~S"""
        <Component foo={ "bar", 1, @a_very_long_name_in_assigns <> @another_extremely_long_name_to_make_the_elixir_formatter_wrap_this_expression } />
        """,
        ~S"""
        <Component foo={
          "bar",
          1,
          @a_very_long_name_in_assigns <>
            @another_extremely_long_name_to_make_the_elixir_formatter_wrap_this_expression
        } />
        """
      )
    end

    test "existing whitespace in string attributes is not altered when there are multiple attributes" do
      # The output may not look "clean", but it didn't look "clean" to begin with, and it's the only
      # way to ensure the formatter doesn't accidentally change the behavior of the resulting code.
      #
      # As with the Elixir formatter, it's important that the semantics of the code remain the same.
      assert_formatter_outputs(
        """
        <Component foo={false} bar="a
          b
          c"
        />
        """,
        """
        <Component
          foo={false}
          bar="a
          b
          c"
        />
        """
      )
    end

    test "existing whitespace in string attributes is not altered when there is only one attribute" do
      assert_formatter_doesnt_change("""
      <foo>
        <bar>
          <baz qux="one
          two" />
        </bar>
      </foo>
      """)
    end

    test "a single extra newline between children is retained" do
      assert_formatter_doesnt_change("""
      <Component>
        foo

        bar
      </Component>
      """)
    end

    test "multiple extra newlines between children are collapsed to one" do
      assert_formatter_outputs(
        """
        <Component>
          foo



          bar
        </Component>
        """,
        """
        <Component>
          foo

          bar
        </Component>
        """
      )
    end

    test "at most one blank newline is retained when an HTML comment exists" do
      assert_formatter_outputs(
        ~S"""
        <div>
          <Component />

          <!-- Comment -->
          <AfterComment />
        </div>
        """,
        ~S"""
        <div>
          <Component />

          <!-- Comment -->
          <AfterComment />
        </div>
        """
      )
    end

    test "inline elements mixed with text are left on the same line by default" do
      assert_formatter_doesnt_change("""
      The <b>Dialog</b> is a stateless component. All event handlers
      had to be defined in the parent <b>LiveView</b>.
      """)

      assert_formatter_doesnt_change("""
      <strong>Surface</strong> <i>v{surface_version()}</i> -
      <a href="http://github.com/msaraiva/surface">github.com/msaraiva/surface</a>.
      """)

      assert_formatter_doesnt_change("""
      This <b>Dialog</b> is a stateful component. Cool!
      """)

      assert_formatter_doesnt_change("""
      <Card>
        <Header>
          A simple card component
        </Header>

        This is the same Card component but now we're using
        <strong>typed slotables</strong> instead of <strong>simple slot entries</strong>.

        <Footer>
          <a href="#" class="card-footer-item">Footer Item 1</a>
          <a href="#" class="card-footer-item">Footer Item 2</a>
        </Footer>
      </Card>
      """)
    end

    test "when element content and tags aren't left on the same line, the next sibling is pushed to its own line" do
      assert_formatter_outputs(
        """
        <div> <div> Hello </div> { 1 + 1 } <p>Goodbye</p> </div>
        """,
        """
        <div>
          <div>
            Hello
          </div>
          {1 + 1} <p>Goodbye</p>
        </div>
        """
      )

      assert_formatter_outputs(
        """
        <div> <p> <span>Hello</span> </p> { 1 + 1 } <p>Goodbye</p> </div>
        """,
        """
        <div>
          <p>
            <span>Hello</span>
          </p>
          {1 + 1} <p>Goodbye</p>
        </div>
        """
      )
    end

    test "(bugfix) newlines aren't removed for no reason" do
      assert_formatter_doesnt_change("""
      <Test />

      Example 1
      <Test />

      Example 2

      <Test />
      """)
    end

    test "whitespace padding in code comments is normalized" do
      assert_formatter_outputs(
        """
        {!--  testing   --}
        <!--     123    -->
        """,
        """
        {!-- testing --}
        <!-- 123 -->
        """
      )
    end

    test "multiline code comments are rendered as-is (except aligning indentation) to avoid false assumptions about how developers want to format comments" do
      # The ending state of these comments is a bit quirky.
      # The formatter refuses to make assumptions about the whitespace in
      # multiline comments, so it renders them verbatim. However, it renders
      # the beginning "tag" indented "properly" as a child of its parent.
      # Developers can respond to this by adjusting the contents in relation
      # to the opening "tag".
      #
      # This is identical to how whitespace is handled for <pre>/<code>/<#MacroComponent>
      assert_formatter_outputs(
        """
        <div>
        {!--


          testing


        --}
        <!--
        Here is a code comment.
          It has multiple lines.
            123

        -->
        </div>
        """,
        """
        <div>
          {!--


          testing


        --}
          <!--
        Here is a code comment.
          It has multiple lines.
            123

        -->
        </div>
        """
      )
    end
  end

  describe "[expressions]" do
    test "Elixir expressions retain the original code snippet" do
      assert_formatter_outputs(
        """
            <div :if = {1 + 1      }>
        {"hello "<>"dolly"}
        </div>




        """,
        """
        <div :if={1 + 1}>
          {"hello " <> "dolly"}
        </div>
        """
      )
    end

    test "shorthand surface syntax (invisible []) is formatted by Elixir code formatter" do
      assert_formatter_outputs(
        "<div class={ foo:        bar }></div>",
        "<div class={foo: bar} />"
      )
    end

    test "expressions in attributes" do
      assert_formatter_outputs(
        """
        <div class={  [1, 2, 3]  } />
        """,
        """
        <div class={[1, 2, 3]} />
        """
      )

      assert_formatter_outputs(
        """
        <div class={foo: "foofoofoofoofoofoofoofoofoofoo", bar: "barbarbarbarbarbarbarbarbarbarbar", baz: "bazbazbazbazbazbazbazbaz"} />
        """,
        """
        <div class={
          foo: "foofoofoofoofoofoofoofoofoofoo",
          bar: "barbarbarbarbarbarbarbarbarbarbar",
          baz: "bazbazbazbazbazbazbazbaz"
        } />
        """
      )
    end

    test "expressions in attributes of deeply nested elements" do
      assert_formatter_outputs(
        """
        <section>
        <div>
        <p class={["foofoofoofoofoofoofoofoofoofoo", "barbarbarbarbarbarbarbarbarbarbar", "bazbazbazbazbazbazbazbaz"]} />
        </div>
        </section>
        """,
        """
        <section>
          <div>
            <p class={[
              "foofoofoofoofoofoofoofoofoofoo",
              "barbarbarbarbarbarbarbarbarbarbar",
              "bazbazbazbazbazbazbazbaz"
            ]} />
          </div>
        </section>
        """
      )
    end

    test "interpolation in string attributes" do
      # Note that the formatter does not remove the extra whitespace at the end of the string.
      # We have no context about whether the whitespace in the given attribute is significant,
      # so we might break code by modifying it. Therefore, the contents of string attributes
      # are left alone other than formatting interpolated expressions.
      assert_formatter_outputs(
        """
        <Component foo={"bar #\{@baz}  "}></Component>
        """,
        """
        <Component foo={"bar #\{@baz}  "} />
        """
      )
    end

    test "numbers are formatted with underscores per the Elixir formatter" do
      assert_formatter_outputs(
        """
        <Component int_prop={1000000000} float_prop={123456789.123456789 } />
        """,
        """
        <Component int_prop={1_000_000_000} float_prop={123_456_789.123456789} />
        """
      )
    end

    test "attribute expressions that are a list merged with a keyword list" do
      assert_formatter_outputs(
        """
        <span class={ "container", "container--dark": @dark_mode } />
        """,
        """
        <span class={"container", "container--dark": @dark_mode} />
        """
      )
    end

    test "attribute expressions with a function call that omits parentheses" do
      assert_formatter_outputs(
        """
        <Component items={ Enum.map @items, & &1.foo }/>
        """,
        """
        <Component items={Enum.map(@items, & &1.foo)} />
        """
      )
    end

    test "expressions that line-wrap are indented properly" do
      assert_formatter_outputs(
        """
        <Component>
          { link "Log out", to: Routes.user_session_path(Endpoint, :delete), method: :delete, class: "container"}
        </Component>
        """,
        """
        <Component>
          {link("Log out",
            to: Routes.user_session_path(Endpoint, :delete),
            method: :delete,
            class: "container"
          )}
        </Component>
        """
      )
    end

    test "(bugfix) attribute expressions that are keyword lists without brackets, with interpolated string keys" do
      assert_formatter_outputs(
        ~S"""
        <Component attr={"a-#{@b}": c} />
        """,
        ~S"""
        <Component attr={"a-#{@b}": c} />
        """
      )
    end

    test "string literals in attributes are not wrapped in expression brackets" do
      assert_formatter_outputs(
        """
        <Component str_prop={ "some_string_value" } />
        """,
        """
        <Component str_prop="some_string_value" />
        """
      )
    end

    test "an expression with only a code comment is turned into a Surface code comment" do
      assert_formatter_outputs(
        """
        { # Foo}
        """,
        """
        {!-- Foo --}
        """
      )
    end

    test "dynamic attributes" do
      assert_formatter_outputs(
        """
        <Foo { ... @bar } />
        """,
        """
        <Foo {...@bar} />
        """
      )

      assert_formatter_outputs(
        """
        <div { ... @attrs } />
        """,
        """
        <div {...@attrs} />
        """
      )

      assert_formatter_outputs(
        """
        <div :attrs={@foo} />
        """,
        """
        <div {...@foo} />
        """
      )

      assert_formatter_outputs(
        """
        <Component :props={@foo} />
        """,
        """
        <Component {...@foo} />
        """
      )

      # keyword with implicit brackets
      assert_formatter_outputs(
        """
        <Component {... foo: @bar, baz: @qux } />
        """,
        """
        <Component {...foo: @bar, baz: @qux} />
        """
      )

      # keyword with explicit brackets
      assert_formatter_outputs(
        """
        <Component {...[foo: @bar, baz: @qux]} />
        """,
        """
        <Component {...[foo: @bar, baz: @qux]} />
        """
      )

      # demonstrate that <#slot arg={@foo} /> isn't collapsed
      assert_formatter_doesnt_change("""
      <#slot arg={@foo} />
      """)
    end

    test "shorthand assigns passthrough attributes" do
      assert_formatter_outputs(
        """
        <Foo {= @bar} />
        """,
        """
        <Foo {=@bar} />
        """
      )

      assert_formatter_outputs(
        """
        <Foo {= bar} />
        """,
        """
        <Foo {=bar} />
        """
      )

      # demonstrate that the formatter is unopinionated about short or longhand
      # in this scenario
      assert_formatter_outputs(
        """
        <Foo bar={@bar} />
        """,
        """
        <Foo bar={@bar} />
        """
      )
    end

    test "root prop" do
      assert_formatter_outputs(
        """
        <MyIf { @var  >  10 } />
        """,
        """
        <MyIf {@var > 10} />
        """
      )
    end

    test "pin operator in expressions" do
      assert_formatter_outputs(
        """
        <div>
          {^ foo}
        </div>
        """,
        """
        <div>
          {^foo}
        </div>
        """
      )

      assert_formatter_outputs(
        """
        <div class="card dark">
          <div class="card-content">
            {^content_ast}
          </div>
          <footer class="card-footer">
            {^code_ast}
          </footer>
        </div>
        """,
        """
        <div class="card dark">
          <div class="card-content">
            {^content_ast}
          </div>
          <footer class="card-footer">
            {^code_ast}
          </footer>
        </div>
        """
      )

      assert_formatter_outputs(
        """
        <pre id={^container_id} class={^class} phx-update="ignore"><code id={^id} class={^class} phx-hook="Highlight">{^code_content}</code></pre>
        """,
        """
        <pre id={^container_id} class={^class} phx-update="ignore"><code id={^id} class={^class} phx-hook="Highlight">{^code_content}</code></pre>
        """
      )
    end

    test "true boolean attribute in directive" do
      assert_formatter_doesnt_change("""
      <div :if={true} />
      """)
    end

    test "strings in attribute expressions with keyword shorthand aren't modified" do
      # By putting at least 2 attributes in the following examples,
      # we make sure to hit `Surface.Formatter.Phases.Render.quoted_strings_with_newlines/1`
      # which is only used with multiple attributes.
      #
      # Rendering a multi-attribute node involves extra specialized logic
      # for dealing with newlines in strings properly.

      assert_formatter_doesnt_change("""
      <Component
        id="foo"
        value={if @bar, do: "baz

        qux"}
      />
      """)

      # deeply nested in blocks
      assert_formatter_doesnt_change("""
      <Component
        id="foo"
        value={if @bar do
          if @baz do
            unless @qux do
              "result
              with
              newlines"
            end
          end
        end}
      />
      """)

      assert_formatter_doesnt_change("""
      <Component
        id="1"
        value={case @foo do
          "bar" ->
            with "qux" <- @baz,
                 :ok <- value?() do
              cond do
                @test != "newliney
                " ->
                  "pass"
              end
            end

          :baz ->
            nil
        end}
      />
      """)
    end
  end

  describe "[blocks]" do
    test "if../if block expressions" do
      assert_formatter_outputs(
        """
        <div> <div>
        {#if @greet}
        <p>
        Hello
        </p>
        {/if}
        </div> </div>
        """,
        """
        <div>
          <div>
            {#if @greet}
              <p>
                Hello
              </p>
            {/if}
          </div>
        </div>
        """
      )
    end

    test "if..elseif..else../if block expressions" do
      assert_formatter_outputs(
        """
        {#if @value == 0}

          <div class="equal">
            Value {@value} is 0
          </div>




        {#elseif     @value   >  0 }
          <div class="greater">

            Value {@value} is greater than 0

          </div>
        {#else}


          <div class="lower">

                  Value {@value} is lower than 0
          </div>
        {/if}
        """,
        """
        {#if @value == 0}
          <div class="equal">
            Value {@value} is 0
          </div>
        {#elseif @value > 0}
          <div class="greater">
            Value {@value} is greater than 0
          </div>
        {#else}
          <div class="lower">
            Value {@value} is lower than 0
          </div>
        {/if}
        """
      )
    end

    test "unless../unless block expressions" do
      assert_formatter_outputs(
        """
        <div> <div>
        {#unless @new_user}
        <p>
        Welcome back!
        </p>
        {/unless}
        </div> </div>
        """,
        """
        <div>
          <div>
            {#unless @new_user}
              <p>
                Welcome back!
              </p>
            {/unless}
          </div>
        </div>
        """
      )
    end

    test "for..else../for block expressions" do
      assert_formatter_outputs(
        """
        {#for item <- @items}

          Item:   {item}
        {#else  }
          No items
        {/for}
        """,
        """
        {#for item <- @items}
          Item: {item}
        {#else}
          No items
        {/for}
        """
      )
    end

    test "for..else../for block expressions with multi-line generator" do
      assert_formatter_outputs(
        """
        {#for item <- @some_prop.items,
        item.type == Some.Long.Complicated.Atom,
        value = item.some_item_property}

          Item:   {item}
        {#else  }
          No items
        {/for}
        """,
        """
        {#for item <- @some_prop.items,
            item.type == Some.Long.Complicated.Atom,
            value = item.some_item_property}
          Item: {item}
        {#else}
          No items
        {/for}
        """
      )
    end

    test "case block expressions" do
      assert_formatter_outputs(
        """
        {#case  @value }

          {#match [first|_]}
            <div {=@class}>
              First {first}
            </div>

          {#match []}


            <div class={@class}>
              Value is empty
            </div>

          {#match "string"}

            <p>String match</p>

          {#match _}

            Value is something else


        {/case}
        """,
        """
        {#case @value}
          {#match [first | _]}
            <div {=@class}>
              First {first}
            </div>
          {#match []}
            <div class={@class}>
              Value is empty
            </div>
          {#match "string"}
            <p>String match</p>
          {#match _}
            Value is something else
        {/case}
        """
      )
    end

    test "nested blocks" do
      assert_formatter_outputs(
        """
        {#if @value == 0}
          {#if @yell}
            <div class="equal">
              VALUE {@value} IS 0
            </div>
          {#else}
            {#if @whisper}
              <div class="equal">
                {@value}...0
              </div>
            {#else}
              <div class="equal">
                Value {@value} is 0
              </div>
            {/if}
          {/if}
        {#else}
          <div class="lower">
              Value {@value} is lower than 0
          </div>
        {/if}
        """,
        """
        {#if @value == 0}
          {#if @yell}
            <div class="equal">
              VALUE {@value} IS 0
            </div>
          {#else}
            {#if @whisper}
              <div class="equal">
                {@value}...0
              </div>
            {#else}
              <div class="equal">
                Value {@value} is 0
              </div>
            {/if}
          {/if}
        {#else}
          <div class="lower">
            Value {@value} is lower than 0
          </div>
        {/if}
        """
      )

      assert_formatter_outputs(
        """
        {#case @foo}
          {#match 1}
            {#case @bar}
              {#match 2}
                <div>
                  foo is 1 and bar is 2
                </div>
              {#match _}
                <div>
                  bar is not 2
                </div>
            {/case}
          {#match _}
            foo is not 1
        {/case}
        """,
        """
        {#case @foo}
          {#match 1}
            {#case @bar}
              {#match 2}
                <div>
                  foo is 1 and bar is 2
                </div>
              {#match _}
                <div>
                  bar is not 2
                </div>
            {/case}
          {#match _}
            foo is not 1
        {/case}
        """
      )
    end

    test "line breaks in blocks" do
      assert_formatter_outputs(
        """
        <div>
          <div>
            <p>
              {#if not is_nil(@some_assign.foo) or not is_nil(@some_assign.bar) or not is_nil(@some_assign.bazzzzzzz.qux)}
                Hello
              {/if}
            </p>
          </div>
        </div>
        """,
        """
        <div>
          <div>
            <p>
              {#if not is_nil(@some_assign.foo) or not is_nil(@some_assign.bar) or
                  not is_nil(@some_assign.bazzzzzzz.qux)}
                Hello
              {/if}
            </p>
          </div>
        </div>
        """
      )
    end

    test "slots" do
      assert_formatter_outputs(
        """
        <div class="mx-6 my-4">
          <#slot {@header}>
            <h1 :if={@title} class="lg:hidden text-md text-neutral-600 mt-4 mb-2 font-semibold leading-loose tracking-wide">
              {@title}
            </h1>
          </#slot>

          <#slot />
        </div>
        """,
        """
        <div class="mx-6 my-4">
          <#slot {@header}>
            <h1
              :if={@title}
              class="lg:hidden text-md text-neutral-600 mt-4 mb-2 font-semibold leading-loose tracking-wide"
            >
              {@title}
            </h1>
          </#slot>

          <#slot />
        </div>
        """
      )
    end
  end

  test "self closing macro components are preserved" do
    assert_formatter_doesnt_change("""
    <#MacroComponent />
    """)
  end

  test "void tags are preserved" do
    assert_formatter_doesnt_change("""
    <embed>
    """)
  end

  test "indent option" do
    assert_formatter_outputs(
      """
      <p>
      <span>
      Indented
      </span>
      </p>
      """,
      """
            <p>
              <span>
                Indented
              </span>
            </p>
      """,
      indent: 3
    )
  end

  test "for docs" do
    assert_formatter_outputs(
      """
       <RootComponent with_many_attributes={ true } causing_this_line_to_wrap={ true} because_it_is_too_long={ "yes, this line is long enough to wrap" }>
         <!--   HTML public comment (hits the browser)   -->
         {!--   Surface private comment (does not hit the browser)   --}



         <div :if={ @show_div }
         class="container">
             <p> Text inside paragraph    </p>
          <span>Text touching parent tags</span>
         </div>

      <Child  items={[%{name: "Option 1", key: 1}, %{name: "Option 2", key:  2},    %{name: "Option 3", key: 3}, %{name: "Option 4", key: 4}]}>
        Default slot contents
      </Child>
      </RootComponent>
      """,
      """
      <RootComponent
        with_many_attributes
        causing_this_line_to_wrap
        because_it_is_too_long="yes, this line is long enough to wrap"
      >
        <!-- HTML public comment (hits the browser) -->
        {!-- Surface private comment (does not hit the browser) --}

        <div :if={@show_div} class="container">
          <p>
            Text inside paragraph
          </p>
          <span>Text touching parent tags</span>
        </div>

        <Child items={[
          %{name: "Option 1", key: 1},
          %{name: "Option 2", key: 2},
          %{name: "Option 3", key: 3},
          %{name: "Option 4", key: 4}
        ]}>
          Default slot contents
        </Child>
      </RootComponent>
      """
    )

    assert_formatter_outputs(
      """
      <div> <p>Hello</p> </div>
      """,
      """
      <div>
        <p>Hello</p>
      </div>
      """
    )

    assert_formatter_outputs(
      """
      <p>Hello</p>





      <p>Goodbye</p>
      """,
      """
      <p>Hello</p>

      <p>Goodbye</p>
      """
    )

    assert_formatter_outputs(
      """
      <section>
        <p>Hello</p>
        <p>and</p>





        <p>Goodbye</p>
      </section>
      """,
      """
      <section>
        <p>Hello</p>
        <p>and</p>

        <p>Goodbye</p>
      </section>
      """
    )
  end

  test "void elements do not have slash in single tag" do
    assert_formatter_outputs(
      """
      <area />
      <base />
      <br />
      <col />
      <hr />
      <img />
      <input />
      <link />
      <meta />
      <param />
      <command />
      <keygen />
      <source />
      """,
      """
      <area>
      <base>
      <br>
      <col>
      <hr>
      <img>
      <input>
      <link>
      <meta>
      <param>
      <command>
      <keygen>
      <source>
      """
    )
  end

  test "<:slot> is formatted" do
    assert_formatter_outputs(
      """
      <div>
        <:header :let={value: value}> Foo </:header>

        <:footer> Foo </:footer>
      </div>
      """,
      """
      <div>
        <:header :let={value: value}>
          Foo
        </:header>

        <:footer>
          Foo
        </:footer>
      </div>
      """
    )
  end

  test "Multi-line strings in attributes aren't indented every time the formatter is ran" do
    # multiple attributes
    assert_formatter_doesnt_change(~S"""
    <div
      class="test"
      x-data={"{
        foo: '#{@bar}',
        baz: '#{@qux}'
      }"}
    />
    """)

    # single attribute
    assert_formatter_doesnt_change(~S"""
    <div x-data={"{
      foo: '#{@bar}',
      baz: '#{@qux}'
    }"} />
    """)

    # nested multiline strings
    assert_formatter_doesnt_change(~S"""
    <div x-data={"{
      foo: '#{@bar}',
      baz: '#{"[
        nested
        multiline
        string
      ]"}'
    }"} />
    """)

    # lists in attributes
    assert_formatter_doesnt_change(~S"""
    <Wrapper>
      <Wrapper>
        {!-- indenting this component allowed us to reproduce a bug --}
        <First
          class={
            "w-full h-12 max-w-full px-4 bg-black-100 hover:bg-black-120 text-base leading-normal
             text-color-bulma-100 box-border border border-solid border-yellow-100 rounded transition
             ease-in placeholder-cyan-100 placeholder-opacity-100 disabled:opacity-50
             disabled:cursor-not-allowed focus:border-red-100 focus:outline-none
             no-scrollbar invalid:shadow-none invalid:border-green-100 #{@class}",
            "pl-11": @left_icon,
            "pr-11": @right_icon,
            "border-green-100": @error
          }
          field={@field}
          opts={[
            placeholder: @placeholder,
            disabled: @disabled,
            required: @required
          ]}
          value={@value}
          focus={@on_focus}
          blur={@on_blur}
        />
      </Wrapper>
    </Wrapper>
    """)

    assert_formatter_outputs(
      ~S"""
      <Second
        class={
          "w-full h-12 max-w-full px-4 bg-x-100 hover:bg-x-120 text-base leading-normal
           text-color-y-100 box-border border border-solid border-k-100 rounded transition
           ease-in placeholder-hhh-100 placeholder-opacity-100 disabled:opacity-50
           disabled:cursor-not-allowed focus:border-m-100 focus:outline-none
           no-scrollbar invalid:shadow-none invalid:border-t-100 #{@class}",
          foo: @foo,
          bar: @bar == "yes"
        }
      />
      """,
      ~S"""
      <Second class={
        "w-full h-12 max-w-full px-4 bg-x-100 hover:bg-x-120 text-base leading-normal
           text-color-y-100 box-border border border-solid border-k-100 rounded transition
           ease-in placeholder-hhh-100 placeholder-opacity-100 disabled:opacity-50
           disabled:cursor-not-allowed focus:border-m-100 focus:outline-none
           no-scrollbar invalid:shadow-none invalid:border-t-100 #{@class}",
        foo: @foo,
        bar: @bar == "yes"
      } />
      """
    )

    assert_formatter_doesnt_change(~S"""
    <Third
      class={
        "w-full h-12 max-w-full px-4 bg-x-100 hover:bg-x-120 text-base leading-normal
         text-color-y-100 box-border border border-solid border-k-100 rounded transition
         ease-in placeholder-h-100 placeholder-opacity-100 disabled:opacity-50
         disabled:cursor-not-allowed focus:border-m-100 focus:outline-none
         no-scrollbar invalid:shadow-none invalid:border-t-100 {@class}",
        @foo,
        @bar
      }
      field={:foo}
    />
    """)

    assert_formatter_doesnt_change(~S"""
    <Fourth class={
      "w-full h-12 max-w-full px-4 bg-x-100 hover:bg-x-120 text-base leading-normal
       text-color-y-100 box-border border border-solid border-k-100 rounded transition
       ease-in placeholder-hhh-100 placeholder-opacity-100 disabled:opacity-50
       disabled:cursor-not-allowed focus:border-m-100 focus:outline-none
       no-scrollbar invalid:shadow-none invalid:border-t-100 #{@class}",
      foo: @foo,
      bar: @bar == "yes"
    } />
    """)
  end

  test "newlines without trailing whitespace in formatted attribute expressions" do
    # This demonstrates a bugfix where the empty newline in between case clauses
    # would be indented with spaces even though there were no contents on the line.
    assert_formatter_outputs(
      ~S"""
      <Component bool_prop attribute={case @foo do
        "bar" ->
          true
        "baz" ->
          false
      end} />
      """,
      ~S"""
      <Component
        bool_prop
        attribute={case @foo do
          "bar" ->
            true

          "baz" ->
            false
        end}
      />
      """
    )
  end

  test "newlines in strings passed to function calls" do
    assert_formatter_doesnt_change(~S"""
    <div>
      {foo("bar
        baz
        qux
      ")}
    </div>
    """)
  end

  test ":hook directive without value" do
    assert_formatter_doesnt_change(~S"""
    <div :hook />
    """)
  end

  test ":debug directive without value" do
    assert_formatter_doesnt_change(~S"""
    <div :debug />
    """)
  end
end
