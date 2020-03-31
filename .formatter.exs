# Used by "mix format"
locals_without_parens = [
  # Surface.Component
  property: 3,
  property: 2,
  context: 1,
  get: 2,
  set: 2,
  set: 3,
  data: 3,
  data: 2
]

[
  locals_without_parens: locals_without_parens,
  export: [locals_without_parens: locals_without_parens],
  inputs: ["{mix,.formatter}.exs", "{config,lib,test}/**/*.{ex,exs}"]
]
