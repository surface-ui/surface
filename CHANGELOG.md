# Changelog

## v0.11.1 (2023-11-07)

  * Warn when module given to `catalogue_test` doesn't exist or is not a component (#711)
  * Fix `inputs_for/3` warnings (#703)

## v0.11.0 (2023-06-02)

  * Add support for Liveview `v0.19` (#692)
  * Fix `Context.get/put` in LiveComponent's `update` callback (#691)
  * Fix issue when passing `css_class` props inside vanilla LV components' slots (#680)

## v0.10.0 (2023-04-18)

  * Add support for Liveview `v0.18.8`
  * Add support for Phoenix `v1.7`
  * Introduce an optional `css_variant` option to `prop` and `data` to support auto-generation of CSS (tailwind)
    variants based on their values
  * Add `embed_sface/1` macro to allow adding `.sface` template as a function component
  * Collect and generate `@import` entries from components to the top of the file to adhere to the CSS spec
  * Fix CSS scope so it can be shared by all function components in the same module, avoiding unnecessary use of `:deep`

## v0.9.4 (2023-02-15)

  * Update `phoenix_live_view` to `v0.18.14`
  * Fix warnings on forms
  * Fix warning on unknown props of function components
  * Remove dependency on `Mix.env()` on re-compiling components at runtime

## v0.9.3 (2023-02-09)

  * Fix error when trying to add the caller's scope_id attr to a MacroComponent

## v0.9.2 (2023-02-06)

  * Compatibility with Liveview >= `v0.18.5`
  * Optimize static props for diff tracking
  * Fix child components' root DOM element not belonging to the parent's scope (#670)
  * Fix missing shortdoc on `surface.init` prevents task discovery from `mix help` (#666)

## v0.9.1 (2022-09-26)

  * Fix dialyzer errors

## v0.9.0 (2022-09-23)

  * Support Liveview `v0.18`

## v0.8.4 (2022-09-26)

  * Fix dialyzer errors

## v0.8.3 (2022-09-22)

  * Add `:global` pseudo-class to the Scoped CSS's API
  * Declare props `container`, `session` and `sticky` on `Surface.LiveView`
  * Fix CSS tokenizer not handling empty strings
  * Fix CSS parser for declarations with commas or variants
  * Fix scoped styles on void elements
  * Fix dialyzer issue in EExEngine (#655)

## v0.8.2 (2022-09-16)

  * Remove compile-time deps from components, avoiding unnecessary recompilation
    of extra files due to transitive deps (#653)
  * Fix components oversized beam files (#651)
  * Fix error on layout templates containing `<style>`

## v0.8.1 (2022-09-02)

  * Fix surface compiler when setting a different `css_output_file` (#646)
  * Fix formatter for `:debug`

## v0.8.0 (2022-09-01)

  * Support scoped CSS styles for components using either inline `<style>` tags or colocated
    `.css` files (#621)
  * Add `render_sface/1` to allow overriding `render/1` and compute/update assigns when using
    external `.sface` files
  * Add `--tailwind` option to `mix surface.init` to bootstrap a project with TailwindCSS support
  * Add `--layouts` option to `mix surface.init` to replace `.heex` layout files with corresponding
    `.sface` files
  * Add `--web-module` option to `mix surface.init` to override the default web module (#638)
  * Support using the `:hook` directive to point to the `default` hook exported in the `.hooks.js` file
  * Add option `from_context` to `prop` and `data` to allow setting values directly from the context
  * Add `Context.put/3` and `Context.get/2` to allow manipulating the context inside
    lifecycle callbacks and `render/1`
  * Add prop `context_put` to `<#slot>` to pass context values directly to a slot without propagating
    context values to other components
  * Add config `:propagate_context_to_slots` to restrict context propagatiion, optimizing diff tracking
  * Add functions `Context.copy_assign/3`, `Context.maybe_copy_assign/3` and `Context.maybe_copy_assign!/3`
  * Add `catalogue_test/1` macro to generate basic tests for catalogue examples and playgrounds
  * Add module `Surface.Catalogue.Examples` to allow defining multiple stateless examples
    in a single module
  * Support editing slot values as text in playgrounds (Catalogue)
  * Fix context propagation in dynamic components
  * Fix context propagation in recursive components
  * New API for Slot arguments and generator (#613)

### Deprecations

  * Deprecate `<InputContext>` in favor of declarative option `from_context`
  * Slots (#613)
    * Option `:args` has been deprecated, use
      * `slot arg: :string` instead of `slot args: [:name]`
      * `slot arg: %{name: :string, age: number}` instead of `slot args: [:name, :age]`
    * Attribute `for` has been deprecated, use `<#slot {@header}>` instead of`<#slot for={@header}>`
    * Attributes `name` and `index` have been deprecated, use `<#slot {col}>` instead of`<#slot name={"col"} index={index}>`
    * Directive `:args` has been deprecated, use
      * `<#slot {@default, name}>` instead of `<#slot :args={name: name}>`
      * `<#slot {@default, name: name, age: age}>` instead of `<#slot :args={name: name, age: age}>`

### Breaking Changes

  * Drop support for Elixir < `v1.12`
  * Context values are no longer automatically propagated through slots. Components that need to
    pass values to the parent scope via slots must explicitly set `propagate_context_to_slots: true`
    in their configuration
  * Slots (#613)
    * New option `:generator_prop` use `slot default, generator_prop: :items` instead of `slot default, args: [item: ^items]`, associated prop `:items` must be of type `:generator`
    * New attribute `generator_value` use `<#slot generator_value={item} />` instead of `<#slot :args={item: item} />`
    * `<#template slot="slot_name">` has been removed in favor of `<:slot_name>` (#575)

## v0.7.6 (2022-09-05)

  * Support Elixir `v1.14`

## v0.7.5 (2022-07-21)

  * Support using vanilla phoenix function components with slots in surface templates

## v0.7.4 (2022-04-18)

  * Optimize the surface compiler for assets generation
  * Improve support for JS hooks in umbrella projects (#591)
  * Suppress `Mix.Tasks.Format` behaviour warning on Elixir < `v0.13`

## v0.7.3 (2022-03-18)

  * Fix loading component prop's default values

## v0.7.2 (2022-03-17)

  * Support more extensions other than `.js` as colocated hooks (`jsx`, `ts` and `tsx`) (#576)
  * Update the `surface.init` task to set up the catalogue to `v0.4`

## v0.7.1 (2022-02-17)

  * Fix wrong target handling in forms
  * Fix setting `@moduledoc false` in catalogue examples (#565)
  * Support Inputs' property `for` as string (#564)

## v0.7.0 (2022-01-13)

  * Support Liveview `v0.17`
  * Support rendering `.sface` templates for regular (dead) views (#543)
  * Support passing properties to slots using the shorthand format, e.g. `<:col label="Name">`
  * Add built-in formatter supporting integration with `mix format` (#535)
  * New `<LiveComponent>` component to inject dynamic live components (#518)
  * Optimize rendering of HTML class attributes literals so they can be treated as static text
  * Add property `for` to `<#slot/>` so it can render the slot content directly (without using `index`)

## v0.6.1 (2021-10-26)

  * Add `surface_formatter` dependency to `mix.exs` when running `mix surface.init` (#507)
  * Allow `Inputs` component inside the `Field` component (#492)
  * Fix using context with external `.sface` templates (#511)
  * Fix attribute name conversion (#512)

## v0.6.0 (2021-10-21)

  * Compatibility with Phoenix `v1.6` and Liveview `v0.16`
  * New `mix surface.init` task
  * Add support for function components
  * Add support for dynamic function components via `<Component>`
  * Add support for recursive function components
  * Optimize change tracking for contexts
  * Fix race condition when compiling tests
  * Fix recompilation of used components

## v0.5.1 (2021-07-13)

  * Add property `values` to form inputs
  * Handle doctype as text
  * Improve error message when `default_translator` is not configured for `ErrorTag` (#449)
  * Raise on invalid attribute/directive in `<#slot>` (#456)
  * Raise error on `{#case}` without `{#match}` (#443)
  * Raise on blocks without expression
  * Fix error line on missing closing tag

## v0.5.0 (2021-06-17)

  * Add `<:slotname>` shorthand for `<#template slot="slotname">`
  * Introduce block expressions for surface templates (e.g., `{#if}..{/if}`)
  * Introduce `{#if}` block expression with support for `{#elseif}` and `{#else}` sub blocks
  * Introduce `{#for}` block expression with support for `{#else}` sub block
  * Introduce `{#unless}` block expression
  * Introduce new shorthand notation for dynamic attributes/props using the `{... }` tagged expression
  * Introduce new shorthand notation for attribute assignment using the `{= }` tagged expression
  * Support private comments using `{!--  --}` for comments that are not supposed to hit the browser
  * Introduce `s-` prefix as an alternative to `:` for directives (i.e. `s-if` and `:if` are now equivalent)
  * Introduce `:values` directive for generating multiple `phx-value-` attributes
  * Added a convert task to aid migrating to the new syntax
  * Evaluate literal attribute values at compile time instead of runtime
  * Fix compile error when using single quotes as attribute value delimiters
  * Add `quote_surface/2` macro to generate Surface AST from template snippets.

### Breaking Changes

  * Replace the sigil `~H` with `~F` to avoid conflict with `HEEx`
  * Replace interpolation delimiters `{{` and `}}` with `{` and `}`
  * Remove support for interpolation inside `<style>...</style>` and `<script>...</script>` nodes
  * ErrorTag: Renamed prop `phx_feedback_for` to `feedback_for`
  * Slot directive `:props` has been renamed to `:args`
  * Option `:props` for the `slot/2` macro has been renamed to `:args`
  * The use of `<template>` has been removed in favor of `<#template>`
  * The use of `<slot>` has been removed in favor of `<#slot>`
  * The use of `<If>` has been removed in favor of `{#if}...{/if}`
  * The use of `<For>` has been removed in favor of `{#for}...{/for}`
  * `MacroComponent.eval_static_props!/3` evaluates and returns only props with option `static: true`

### Deprecations

  * Support for passing non-string attribute values as literals (i.e. `selected=true` or `tabindex=3`) has been removed.
    Any non-string value should be passed as an expression (i.e. `selected={true}`)

## v0.4.1 (2021-05-26)

  * Fix warning on Phoenix Live View >= 1.15.6

## v0.4.0 (2021-05-01)

  * Call render when defined in slotable components (#283)
  * Support defining form fields as strings. Consequently, fields defined as literal strings will
    no longer be auto-converted to `:atom` and will keep the original value (#319)
  * Deprecate auto-conversion of attribute values passed as string literals into atoms
  * Do not encode HTML entities when passing attribute values as string literals (#323)
  * Extract the Markdown macro component in its repository (#316)
  * Renamed `Surface.Components.Button` to `Surface.Components.Link.Button` (#350)

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
