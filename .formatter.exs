# Used by "mix format"
locals_without_parens = [
  # Surface.Component
  prop: 3,
  prop: 2,
  data: 3,
  data: 2,
  slot: 1,
  slot: 2,
  catalogue_test: 1,
  catalogue_test: 2,
  load_asset: 2,
  embed_sface: 1
]

[
  locals_without_parens: locals_without_parens,
  export: [locals_without_parens: locals_without_parens],
  line_length: 115,
  inputs: ["{mix,.formatter}.exs", "{config,lib,test}/**/*.{ex,exs}"]
]
