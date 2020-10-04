# Changelog

## v0.1.0-dev

  * Update LiveView to v0.15-dev
  * Make `<slot>` mandatory instead of `inner_content`
  * Add support for co-located template files using `.sface` suffix
  * Add `Surface.init/1` to initialize internal assigns when not using `Surface.LiveView`
  * Add `:props` directive to pass dynamic props to a component
  * Add `:attrs` directive to pass dynamic attributes to a tag
  * Add new modifiers `index` and `with_index` for `:for`.
  * Update html tag generation to remove the tag if it's value computes to nil
  * Add support for a `transform/1` callback to allow components to manipulate its
    own node at compile-time.
  * New form controls: `<Inputs>`, `<Checkbox>`, `<Select>`, `<MultipleSelect>`,
    `<HiddenInputs>` and `<OptionsForSelect>`.

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
