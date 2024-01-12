defmodule Mix.Tasks.Surface.Init.ExPatcher.Move do
  @moduledoc false

  alias Sourceror.Zipper, as: Z

  def apply(zipper, moves) do
    moves
    |> Enum.reverse()
    |> Enum.reduce(zipper, & &1.(&2))
  end

  def inspect_node(zipper, label \\ "Node") do
    if zipper do
      Z.node(zipper)
    else
      zipper
    end
    |> IO.inspect(label: label)

    zipper
  end

  # For any node

  def find_code(zipper, string) do
    zipper
    |> Z.node()
    |> Z.zip()
    |> Z.find(fn node -> Sourceror.to_string(node) == string end)
  end

  def find_code_containing(zipper, string) do
    zipper
    |> Z.node()
    |> Z.zip()
    |> Z.find(fn node -> node |> Sourceror.to_string() |> String.contains?(string) end)
  end

  # For block nodes

  def find_child(zipper, predicate) do
    zipper
    |> case do
      %Sourceror.Zipper{node: {name, _, _}} when name != :__block__ ->
        zipper

      %Sourceror.Zipper{} ->
        Z.down(zipper)
    end
    |> return_match_or_move_right(predicate)
  end

  def find_child_with_code(zipper, string) when is_binary(string) do
    find_child(zipper, fn node -> Sourceror.to_string(node) == string end)
  end

  def find_child_with_code(zipper, fun) when is_function(fun) do
    find_child(zipper, fn node -> fun.(Sourceror.to_string(node)) end)
  end

  def find_call(zipper, name, predicate \\ fn _ -> true end) do
    find_child(zipper, fn
      {^name, _, args} ->
        predicate.(args)

      _ ->
        false
    end)
  end

  def find_def(zipper, name, predicate \\ fn _ -> true end) do
    find_child(zipper, fn
      {:def, _, [{^name, _, args} | _]} ->
        predicate.(args)

      _ ->
        false
    end)
  end

  def find_defp(zipper, name, predicate \\ fn _ -> true end) do
    find_child(zipper, fn
      {:defp, _, [{^name, _, args} | _]} ->
        predicate.(args)

      _ ->
        false
    end)
  end

  def find_defp_with_args(zipper, name, predicate) do
    find_child(zipper, fn
      {:defp, _, [{^name, _, node_args} | _]} ->
        args = Enum.map(node_args, &Sourceror.to_string/1)
        predicate.(args)

      _ ->
        false
    end)
  end

  def find_call_with_args_and_opt(zipper, name, args, opt) do
    find_call(zipper, name, fn
      node_args ->
        {opts, node_args} = List.pop_at(node_args, -1)
        args == Enum.map(node_args, &Sourceror.to_string/1) && find_keyword(opts |> Z.zip(), opt)
    end)
  end

  def find_call_with_args(zipper, name, predicate) do
    find_call(zipper, name, fn
      node_args ->
        args = Enum.map(node_args, &Sourceror.to_string/1)
        predicate.(args)
    end)
  end

  def enter_call(zipper, name, predicate \\ fn _ -> true end) do
    zipper
    |> find_call(name, predicate)
    |> body()
  end

  # For the call nodes

  def last_arg(zipper) do
    # TODO: Validate if it's a call
    zipper
    |> Z.down()
    |> Z.rightmost()
  end

  def body(zipper) do
    zipper
    |> last_arg()
    |> find_keyword(:do)
    |> Z.down()
    |> Z.right()
  end

  def last_child(zipper) do
    zipper
    |> Z.down()
    |> Z.rightmost()
  end

  # For list nodes

  def find_list_item(zipper, predicate) do
    # TODO: Validate if it's a list
    zipper
    |> Z.down()
    |> Z.down()
    |> return_match_or_move_right(predicate)
  end

  def find_list_item_with_code(zipper, string) do
    find_list_item(zipper, fn node -> Sourceror.to_string(node) == string end)
  end

  def find_list_item_containing(zipper, string) do
    find_list_item(zipper, fn node -> node |> Sourceror.to_string() |> String.contains?(string) end)
  end

  # For keyword list nodes

  def find_keyword(zipper, key) when is_atom(key) do
    # TODO: Validate if it's keyword list
    find_keyword(zipper, [key])
  end

  def find_keyword(zipper, [key | rest]) do
    zipper =
      zipper
      |> normalize_opts()
      |> find_child(&match?({{:__block__, _, [^key]}, _}, &1))

    if rest == [] do
      zipper
    else
      zipper
      |> Z.down()
      |> Z.right()
      |> find_keyword(rest)
    end
  end

  # For keyword nodes

  def value(zipper) do
    # TODO: validate it's a keyword
    zipper
    |> Z.down()
    |> Z.right()
  end

  # Private API

  defp return_match_or_move_right(nil, _predicate) do
    nil
  end

  defp return_match_or_move_right(zipper, predicate) do
    if zipper |> Z.node() |> predicate.() do
      zipper
    else
      zipper |> Z.right() |> return_match_or_move_right(predicate)
    end
  end

  defp normalize_opts(zipper) do
    case zipper do
      %Sourceror.Zipper{node: [{{:__block__, _, _}, _} | _]} ->
        zipper

      %Sourceror.Zipper{} ->
        Z.down(zipper)
    end
  end
end
