defmodule Surface.Components.Form.RangeInputTest do
  use ExUnit.Case

  alias Surface.Components.Form.RangeInput, warn: false

  import ComponentTestHelper

  describe "Without LiveView" do
    test "empty input" do
      code = """
      <RangeInput form="volume" field="percent" min="0" max="100"/>
      """

      assert render_live(code) =~ """
             <input id="volume_percent" max="100" min="0" name="volume[percent]" type="range"/>
             """
    end

    test "setting the value" do
      code = """
      <RangeInput form="volume" field="percent" min="0" max="100" value="25"/>
      """

      assert render_live(code) =~ """
             <input id="volume_percent" max="100" min="0" name="volume[percent]" type="range" value="25"/>
             """
    end

    test "passing other options" do
      code = """
      <RangeInput form="volume" field="percent" min="0" max="100" opts={{ id: "myid" }} />
      """

      assert render_live(code) =~ """
             <input id="myid" max="100" min="0" name="volume[percent]" type="range"/>
             """
    end
  end
end
