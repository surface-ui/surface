defmodule Surface.BaseComponent do
  @callback render_code(mod_str :: binary, attributes :: any, children_iolist :: any, mod :: module, caller :: Macro.Env.t) :: any
end
