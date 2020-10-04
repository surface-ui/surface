# Used by "mix format"
locals_without_parens = [
  # Surface.Component
  prop: 3,
  prop: 2,
  data: 3,
  data: 2,
  slot: 1,
  slot: 2
]

[
  locals_without_parens: locals_without_parens,
  export: [locals_without_parens: locals_without_parens],
  inputs: ["{mix,.formatter}.exs", "{config,lib,test}/**/*.{ex,exs}"]
]
