# Changelog

## v0.3.2 (2021-03-19)

  * Warn if prop is required and has default value (#282)
  * Warn if slot is required and has a fallback content (#296)
  * Warn on `LiveComponent` with another `LiveComponent` as root
  * Support escaped three double-quotes in `Markdown` content
  * Improve `Label` component compatibility with Phoenix `label/2` (#284)
  * Update props according to new types (#297)
  * Fix copying JS hooks multiple times (#294)

## v0.3.1 (2021-03-05)

  * Fix `index.js` generation when no hooks are available
  * Fix loading hooks from dependencies
  * Support `<Link>` with scheme (#273)

## v0.3.0 (2021-02-24)

  * Autoload JS hooks via new surface compiler (#271)
  * New `<Link>` and `<Label>` implementation without depending on `content_tag` to allow receiving
    child components in slots (#264)
  * Don't validate undefined assigns outside render (#263)
  * Load subject's default props values before sending them to playgrounds

## v0.2.1 (2021-02-01)

  * Allow different catalogue options for examples and playgrounds

## v0.2.0 (2021-01-27)

  * Introduce new testing API using `render_surface/1`
  * Add experimental support to create examples and playgrounds for catalogues
  * Raises compile error if slots are not declared
  * Raises compile error on duplicate built-in assign
  * Allow defining the assign name for slot through the :as option (#230)
  * Implement the `:show` directive via hidden attribute (#244)
  * Add new `<DateSelectComponent>` component
  * Remove default value from `Form` method prop
  * Reintroduce opts prop for the `<Select>` component
  * Fix markdown syntax warning in `<Form>` docs
  * Fix error when using :if + :props in slots (#224)
  * Fix line offset when using single-line `~H` variants (#246)
  * Fix UnicodeConversionError when using string literals inside interpolation

## v0.1.1 (2020-11-28)

  * Add explicit props for the main opts of Checkbox, Select, MultipleSelect, FileInput and Form (#215).
  * Add new `slot_assigned?/1` macro to check if a slot has been filled in (#211).
  * Fix attribute value encoding

## v0.1.0 (2020-11-23)

  * Update liveview to v0.15
  * Add new `Surface.Components.Form.ErrorTag` to render error messages in forms (#199).
  * Disable validation for required props if `:props` is passed (#204)

## v0.1.0-rc.2 (2020-11-04)

  * Update liveview to latest v0.15-dev (f986171)
  * New wrapper components `Surface.Components.{For, If}` for when the `:for` and `:if` directives aren't sufficient (#184)
  * Allow double braces within interpolation (#171)
  * Add new `Surface.Components.FieldContext` to support form fields without wrapping divs (#172)
  * Improve error message for unloaded modules (#174)
  * Fix issue with `:for` modifiers on components (#176)
  * Expose form instance as slot prop on `Surface.Components.Form` (#183)
  * Don't initialize data assigns without default value (#195)

## v0.1.0-rc.1 (2020-10-21)

  * Fix support for Elixir >= v1.11
  * Update liveview to latest v0.15-dev (597c5dd)
  * Add undefined assign check for `Surface.{LiveComponent,Component,LiveView}`
  * New form controls wrappers: `<DateTimeSelect>` and `<TimeSelect>`.
  * Force recompilation of the parent component after fixing errors on any of its children.

## v0.1.0-rc.0 (2020-10-06)

  * Update LiveView to v0.15-dev (0f592a4).
  * Make `<slot>` mandatory instead of `inner_content`.
  * Add attribute `index` to `<slot>` to allow rendering individual named slot items.
  * Rename macro `property` to `prop`.
  * Remove macro `context` and add a `<Context>` component to be used instead.
  * Rename directives `:on-phx-[event]` to `:on-[event]`.
  * Add support for co-located template files using `.sface` suffix.
  * Add `Surface.init/1` to initialize internal assigns when not using `Surface.LiveView`.
  * Add `:props` directive to pass dynamic props to a component.
  * Add `:attrs` directive to pass dynamic attributes to a tag.
  * Add new modifiers `index` and `with_index` for `:for`.
  * Update html tag generation to remove the tag if it's value computes to `nil`.
  * Add support for a `transform/1` callback to allow components to manipulate its
    own node at compile-time.
  * New form controls: `<Inputs>`, `<Checkbox>`, `<Select>`, `<MultipleSelect>`,
    `<HiddenInputs>`, `<FileInput>` and `<OptionsForSelect>`.

## v0.1.0-alpha.2 (2020-06-09)

  * New Markdown component
  * New Link component
  * New form components Form, Field, TextArea, Label, TextInput, RadioButton,
    HiddenInput, ColorInput, DateInput, DateTimeLocalInput, EmailInput, NumberInput,
    PasswordInput, RangeInput, SearchInput, TelephoneInput, TimeInput, UrlInput,
    Reset and Submit.
  * Automatically define a required :id property for live components that implement
    `handle_event/3`
  * New config API for components
  * Update LiveView to v0.13

## v0.1.0-alpha.1 (2020-04-13)

  * Add support for slots
  * Add built-in LivePath and LiveRedirect components
  * Drop automatic camel-to-kebab conversion for CSS class name
  * Drop support for `inner_content.()`. Use `inner_content.([])` instead
  * Update LiveView to v0.11.1

## v0.1.0-alpha.0 (2020-02-26)

  * Initial alpha release
