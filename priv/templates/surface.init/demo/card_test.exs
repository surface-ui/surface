defmodule <%= inspect(web_module) %>.Components.CardTest do
  use <%= inspect(web_module) %>.ConnCase, async: true
  use Surface.LiveViewTest

  catalogue_test <%= inspect(web_module) %>.Components.Card
end
