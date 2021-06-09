# Migrating from `v0.4.x` to `v0.5.x`

This guide provides detailed instructions on how to run the built-in converter to
translate Surface `v0.4` code into the new `v0.5` syntax.

## Limitations of the converter

  * By design, the converter doesn't touch Surface code inside documentation or macro components. If you have
  any code written inside `<!-- -->` or `<#Raw>...</#Raw>`, you need to convert it manually.

  * The replacement of `~H` with `~F` happens globally in a `.ex` (or `.exs`) file, i.e., the converter will
  replace any occurrence of `~H` followed by `"""`, `"`, `[`, `(` or `{`, including occurrences found in comments.

  * Running the converter on a project that has already been converted may generate invalid code. If anything goes
  wrong with the conversion, make sure you revert the changes before running it again.

## Before converting the project

  1. Make sure you have commited your work or have a proper backup before running the converter. It may touch
  a lot of files so it's recommended to have a safe way to rollback the changes in case anything goes wrong.

  2. Check your dependencies. For a safer migration, all dependencies providing Surface components should
  be converted before running the converter on the main project. Otherwise, you might not be able to compile your
  project in case any of those dependencies is using the invalid old syntax. If the dependency you need has not been
  updated yet, please consider running the converter against it and submitting a PR with the updated code. The steps
  to convert a dependency are the same decribed in this guide.

## Steps to run the converter

Update your `.formatter` informing about `.sface` files and any additional folder where you might have any component
to be converted:

```
[
  surface_inputs: ["{lib,test}/**/*.{ex,exs,sface}", "priv/catalogue/**/*.{ex,exs,sface}"],
  ...
]

```

Update `mix.exs` to use the new version:

```
  defp deps do
    [
      {:surface, github: "surface-ui/surface"},
      ...
    ]
  end
```

Compile the dependencies:

```
mix clean && mix deps.get && mix deps.compile
```

Run the converter:

```
mix surface.convert
```

Compile the converted project:

```
mix compile
```

## Expected changes

| Subject                      | Examples (Old syntax -> New syntax)                                      |
| ---------------------------- | ------------------------------------------------------------------------ |
| Sigil                        | `~H"""` -> `~F"""`                                                       |
| Interpolation                | `{{@value}}` -> `{@value}`                                             |
| Templates                    | `<template>` -> `<#template>`                                            |
| Slots                        | `<slot>` -> `<#slot>`                                                    |
| If                           | `<If condition={{ expr }}>` -> `{#if expr}`                              |
| For                          | `<For each={{ expr }}>` -> `{#for expr}`                                 |
| Interpolation in attr values | `id="id_{{@id}}"` -> `id={"id_#{@id}"}`                                  |
| Non-string attr values       | `selected=true` -> `selected={true}` <br> `tabindex=1` -> `tabindex={1}` |

## Reporting issues

In case you run into any trouble while running the converter, please open an issue at https://github.com/surface-ui/surface/issues/
providing detailed information about the problem, including the error message (if any) and a snippet of the
related code.