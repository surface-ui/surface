# Migrating from `v0.7.x` to `v0.8.x`

Historically, most of the updates that require changes in your code, can be automatically
done by `mix surface.convert`, however, as we move forward to unify the API with Liveview, some of the
changes in `v0.8` may require user intervention as the converter might not be able to automatically
patch the project. For such cases, we adjusted the compiler to provide assertive warnings to help you
with the migration process. The main changes of that kind are related to the context API.

## The new Context API

The context API have been extended and fully redesigned to improve its use and make it more friendly for
diff tracking. The compiler is able now to detect many cases where the use of contexts might impact
performance and suggest one or more alternative approaches to achieve the same goal. We recommend you
to carefully read each warning with care and follow the instructions that best suit you perticular case.

Aside from the warnings, the only breaking change is that context values are no longer automatically
propagated through slots. Components that need to pass values to the parent scope via slots must
explicitly set `propagate_context_to_slots: true` in `config.exs`:

```elixir
config :surface, :components, [
  {Surface.Components.Form, propagate_context_to_slots: true},
]
```

The compile will emit a warning whenever it finds a component that can potentially propagate context
values through slots. If you don't want to use contexts at all, you need to set `propagate_context_to_slots`
to `false` to suppress the warning for that component.

> **NOTE:** The following built-in Surface components are already configured to propagate context to slots:
> `Surface.Components.Form,`, `Surface.Components.Form.Field`, `Surface.Components.Form.FieldContext` and
> `Surface.Components.Form.Inputs`.

## Running `mix surface.convert`

This guide provides detailed instructions on how to run the built-in converter to automatically
apply required changes to your project's source code to make it compatible
with Surface `v0.8`.

> **NOTE:**  The current converter was designed to run against projects depending on Surface `>= v0.6.x`.
> If you're using an older version, you should first update it to each one of the previous versions
> all the way to `v0.7`. See:
> * [Migrating from v0.5.x to v0.6.x](https://github.com/surface-ui/surface/blob/v0.7.0/MIGRATING.md)
> * [Migrating from v0.4.x to v0.5.x](https://github.com/surface-ui/surface/blob/v0.6.0/MIGRATING.md)

### Limitations of the converter

  * By design, the converter doesn't touch Surface code inside documentation or macro components. If you have
  any code written inside `<!-- -->` or `<#Raw>...</#Raw>`, you need to convert it manually.

  * The replacement of `slot name, props: [...]` with `slot name, args: [...]` happens globally in a `.ex` (or `.exs`) file,
  i.e., the converter will replace any occurrence of it, even if found in comments.

  * Running the converter on a project that has already been converted may generate invalid code. If anything goes
  wrong with the conversion, make sure you revert the changes before running it again.

## Before converting the project

  1. Make sure you have committed your work or have a proper backup before running the converter. It may touch
  a lot of files so it's recommended to have a safe way to rollback the changes in case anything goes wrong.

  2. Check your dependencies. In case your project depends on a library using an older Surface version, it might start
  emitting warnings or even fail to compile after updating Surface. If that's the case, please consider running
  the converter against it and submitting a PR with the updated code. The steps to convert a dependency are the
  same described in this guide.

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
      {:surface, "~> 0.7.0"},
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

## Expected changes

| Subject                       | Examples (Old syntax -> New syntax)                                                           |
| ----------------------------- | --------------------------------------------------------------------------------------------- |
| Templates                     | &bull; `<#template>` -> `<:default>`  <br> &bull; `<#template slot="header">` -> `<:header>`  |

## Reporting issues

In case you run into any trouble while running the converter, please open an issue at https://github.com/surface-ui/surface/issues/
providing detailed information about the problem, including the error message (if any) and a snippet of the
related code.
