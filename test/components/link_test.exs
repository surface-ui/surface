defmodule Surface.Components.LinkTest do
  use ExUnit.Case

  alias Surface.Components.Link, warn: false

  import ComponentTestHelper

  describe "Without LiveView" do
    test "creates a link with label" do
      code = """
      <Link label="user" to="/users/1" />
      """

      assert render_live(code) =~ """
             <a href="/users/1">user</a>
             """
    end

    test "creates a link without label" do
      code = """
      <Link to="/users/1" />
      """

      assert render_live(code) =~ """
             <a href="/users/1"></a>
             """
    end

    test "creates a link with default slot" do
      code = """
      <Link to="/users/1"><span>user</span></Link>
      """

      assert render_live(code) =~ """
             <a href="/users/1"><span>user</span></a>
             """
    end

    test "setting the class" do
      code = """
      <Link label="user" to="/users/1" class="link" />
      """

      assert render_live(code) =~ """
             <a class="link" href="/users/1">user</a>
             """
    end

    test "passing other options" do
      code = """
      <Link label="user" to="/users/1" class="link" opts={{ method: :delete, data: [confirm: "Really?"], csrf_token: "token" }} />
      """

      assert render_live(code) =~ """
             <a class="link" data-confirm="Really?" data-csrf="token" data-method="delete" data-to="/users/1" href="/users/1" rel="nofollow">user</a>
             """
    end
  end
end
