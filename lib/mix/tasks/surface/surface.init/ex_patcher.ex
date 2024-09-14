defmodule Mix.Tasks.Surface.Init.ExPatcher do
  @moduledoc false

  alias Sourceror.Zipper, as: Z
  alias Mix.Tasks.Surface.Init.ExPatcher.Move

  @derive {Inspect, only: [:code, :result, :node]}
  defstruct [:zipper, :node, :code, :moves, :result]

  @line_break ["\n", "\r\n", "\r"]

  def parse_string!(code) do
    zipper = code |> Sourceror.parse_string!() |> Z.zip()

    %__MODULE__{
      code: code,
      result: :unpatched,
      zipper: zipper,
      node: Z.node(zipper)
    }
  end

  def parse_file!(file) do
    case File.read(file) do
      {:ok, code} ->
        parse_string!(code)

      {:error, :enoent} ->
        %__MODULE__{result: :file_not_found}

      {:error, _reason} ->
        %__MODULE__{result: :cannot_read_file}
    end
  end

  def zipper(%__MODULE__{zipper: zipper}) do
    zipper
  end

  def result(%__MODULE__{result: result}) do
    result
  end

  def to_node(%__MODULE__{node: node}) do
    node
  end

  def valid?(%__MODULE__{node: node}) do
    node != nil
  end

  def node_to_string(patcher, opts \\ []) do
    patcher |> to_node() |> Sourceror.to_string(opts)
  end

  def inspect_code(%__MODULE__{code: code} = patcher, label \\ "CODE") do
    IO.puts("--- BEGIN #{label} ---")
    IO.puts(code)
    IO.puts("--- END #{label} ---")
    patcher
  end

  def inspect_node(patcher, label \\ "NODE") do
    IO.puts("--- BEGIN #{label} ---")
    patcher |> to_node() |> IO.inspect()
    IO.puts("--- END #{label} ---")
    patcher
  end

  def inspect_zipper(patcher, label \\ "ZIPPER") do
    IO.puts("--- BEGIN #{label} ---")
    patcher |> zipper() |> IO.inspect()
    IO.puts("--- END #{label} ---")
    patcher
  end

  defp move(%__MODULE__{result: result} = patcher, _move) when result != :unpatched do
    patcher
  end

  defp move(%__MODULE__{zipper: zipper} = patcher, move) do
    zipper = move.(zipper)

    {node, result} =
      if zipper do
        {Z.node(zipper), result(patcher)}
      else
        {nil, :cannot_patch}
      end

    %__MODULE__{patcher | zipper: zipper, node: node, result: result}
  end

  def find_code(patcher, string) do
    move(patcher, &Move.find_code(&1, string))
  end

  def find_code_containing(patcher, string) do
    move(patcher, &Move.find_code_containing(&1, string))
  end

  def find_call(patcher, name, predicate \\ fn _ -> true end) do
    move(patcher, &Move.find_call(&1, name, predicate))
  end

  def enter_call(patcher, name, predicate \\ fn _ -> true end) do
    move(patcher, &Move.enter_call(&1, name, predicate))
  end

  def find_call_with_args_and_opt(patcher, name, args, opt) do
    move(patcher, &Move.find_call_with_args_and_opt(&1, name, args, opt))
  end

  def find_call_with_args(patcher, name, predicate) do
    move(patcher, &Move.find_call_with_args(&1, name, predicate))
  end

  def find_def(patcher, name, predicate \\ fn _ -> true end) do
    move(patcher, &Move.find_def(&1, name, predicate))
  end

  def find_defp(patcher, name, predicate \\ fn _ -> true end) do
    move(patcher, &Move.find_defp(&1, name, predicate))
  end

  def find_defp_with_args(patcher, name, predicate) do
    move(patcher, &Move.find_defp_with_args(&1, name, predicate))
  end

  def enter_def(patcher, name) do
    patcher
    |> find_def(name)
    |> body()
  end

  def enter_defp(patcher, name) do
    patcher
    |> find_defp(name)
    |> body()
  end

  def enter_defmodule(patcher) do
    enter_call(patcher, :defmodule)
  end

  def enter_defmodule(patcher, module) do
    patcher
    |> find_call_with_args_and_opt(:defmodule, [inspect(module)], [:do])
    |> body()
  end

  def last_arg(patcher) do
    move(patcher, &Move.last_arg(&1))
  end

  def body(patcher) do
    move(patcher, &Move.body(&1))
  end

  def find_keyword(patcher, keys) do
    move(patcher, &Move.find_keyword(&1, keys))
  end

  def find_keyword_value(patcher, keys) do
    patcher
    |> find_keyword(keys)
    |> value()
  end

  def value(patcher) do
    move(patcher, &Move.value(&1))
  end

  def down(patcher) do
    move(patcher, &Z.down(&1))
  end

  def last_child(patcher) do
    move(patcher, &Move.last_child(&1))
  end

  def find_child_with_code(patcher, string) do
    move(patcher, &Move.find_child_with_code(&1, string))
  end

  def find_list_item_with_code(patcher, string) do
    move(patcher, &Move.find_list_item_with_code(&1, string))
  end

  def find_list_item_containing(patcher, string) do
    move(patcher, &Move.find_list_item_containing(&1, string))
  end

  def replace(patcher, fun) when is_function(fun) do
    patch(patcher, fn zipper ->
      zipper
      |> Z.node()
      |> Sourceror.to_string()
      |> fun.()
    end)
  end

  def replace(patcher, code) when is_binary(code) do
    patch(patcher, fn _zipper -> code end)
  end

  def replace_code(%__MODULE__{code: code} = patcher, fun) when is_function(fun) do
    patch(patcher, [preserve_indentation: false], fn zipper ->
      node = Z.node(zipper)
      range = Sourceror.get_range(node, include_comments: true)
      code_to_replace = get_code_by_range(code, range)
      fun.(code_to_replace)
    end)
  end

  def insert_after(patcher, string) do
    node = Sourceror.parse_string!(string)

    patch(patcher, fn zipper ->
      zipper
      |> Z.down()
      |> Z.insert_right(node)
      |> Z.up()
      |> Z.node()
      |> Sourceror.to_string()
    end)
  end

  def insert_keyword(patcher, key, value) do
    keyword = build_keyword_node(key, value)

    patch(patcher, [preserve_indentation: false], fn zipper ->
      zipper
      |> Z.insert_child(keyword)
      |> Z.node()
      |> Sourceror.to_string(format: :splicing)
      |> String.trim()
    end)
  end

  def append_keyword(patcher, key, value) do
    keyword = build_keyword_node(key, value)

    patch(patcher, fn zipper ->
      zipper
      |> Z.down()
      |> Z.append_child(keyword)
      |> Z.up()
      |> Z.node()
      |> Sourceror.to_string()
    end)
  end

  def append_list_item(patcher, string, opts \\ []) do
    opts = Keyword.merge([preserve_indentation: false], opts)
    node = Sourceror.parse_string!(string)

    patch(patcher, opts, fn zipper ->
      zipper
      |> Z.down()
      |> Z.append_child(node)
      |> Z.up()
      |> Z.node()
      |> Sourceror.to_string(to_string_opts())
    end)
  end

  def prepend_list_item(patcher, string, opts \\ []) do
    opts = Keyword.merge([preserve_indentation: false], opts)
    node = Sourceror.parse_string!(string)

    patch(patcher, opts, fn zipper ->
      zipper
      |> Z.down()
      |> Z.insert_child(node)
      |> Z.up()
      |> Z.node()
      |> Sourceror.to_string(to_string_opts())
    end)
  end

  def halt_if(%__MODULE__{result: result} = patcher, _predicate, _new_status) when result != :unpatched do
    patcher
  end

  def halt_if(patcher, predicate, result) do
    case predicate.(patcher) do
      %__MODULE__{node: nil} -> patcher
      nil -> patcher
      false -> patcher
      _ -> set_result(patcher, result)
    end
  end

  def set_result(patcher, status) do
    %__MODULE__{patcher | result: status}
  end

  def append_code(patcher, text_to_append) do
    patch(patcher, fn zipper ->
      zipper_append_patch(zipper, text_to_append, code(patcher))
    end)
  end

  def append_child_code(patcher, text_to_append) do
    patch(patcher, fn zipper ->
      # If possible, we try to replace the last child so the whole block
      # doesn't have to be formatted when using `Z.append_child/2`
      case Move.last_child(zipper) do
        nil ->
          node = Sourceror.parse_string!(text_to_append)

          zipper
          |> Z.append_child(node)
          |> Z.node()
          |> Sourceror.to_string()

        last_child_zipper ->
          zipper_append_patch(last_child_zipper, text_to_append, code(patcher))
      end
    end)
  end

  def append_child(patcher, string) do
    patch(patcher, fn zipper ->
      # If possible, we try to replace the last child so the whole block
      # doesn't have to be formatted when using `Z.append_child/2`
      case Move.last_child(zipper) do
        nil ->
          node = Sourceror.parse_string!(string)

          zipper
          |> Z.append_child(node)
          |> Z.node()
          |> Sourceror.to_string()

        %Sourceror.Zipper{node: {:., _, _}} ->
          # We can't get the range of the dot call in a qualified call like
          # `foo.bar()`, so we apply the patch to the parent. We get into this
          # situation when the qualified call has no arguments: the first child
          # will be a dot call of the form `{:., meta, [left, identifier]}`
          # where `identifier` is a bare atom, like `:compilers`. The line
          # metadata for the identifier lives in the parent call, making it
          # impossible to generate a patch for the child call alone.
          append_child_patch(zipper, string)

        %Sourceror.Zipper{} = last_child_zipper ->
          append_child_patch(last_child_zipper, string)
      end
    end)
  end

  defp append_child_patch(zipper, string) do
    node = Z.node(zipper)
    range = Sourceror.get_range(node, include_comments: true)
    updated_code = Sourceror.parse_string!(Sourceror.to_string(node) <> string)

    change =
      zipper
      |> Z.replace(updated_code)
      |> Z.node()
      |> Sourceror.to_string()

    %{change: change, range: range}
  end

  defp zipper_append_patch(zipper, text_to_append, original_code) do
    case zipper do
      {{:., _, _}, _} ->
        # We can't get the range of the dot call in a qualified call like
        # `foo.bar()`, so we apply the patch to the parent. We get into this
        # situation when the qualified call has no arguments: the first child
        # will be a dot call of the form `{:., meta, [left, identifier]}`
        # where `identifier` is a bare atom, like `:compilers`. The line
        # metadata for the identifier lives in the parent call, making it
        # impossible to generate a patch for the child call alone.
        append_child_patch(zipper, text_to_append)

      _ ->
        range = Sourceror.get_range(Z.node(zipper))
        node_code = get_code_by_range(original_code, range)
        indent = Keyword.get(range.start, :column, 1) - 1
        change = node_code <> "\n" <> add_indentation(text_to_append, indent)
        %{change: change, range: range, preserve_indentation: false}
    end
  end

  def patch(patcher, opts \\ [], fun)

  def patch(%__MODULE__{result: result} = patcher, _opts, _fun) when result != :unpatched do
    patcher
  end

  def patch(patcher, opts, fun) do
    zipper = zipper(patcher)

    patch =
      case fun.(zipper) do
        change when is_binary(change) ->
          range = zipper |> Z.node() |> Sourceror.get_range(include_comments: true)
          Map.merge(%{change: change, range: range}, Map.new(opts))

        patch ->
          patch
      end

    updated_code = patcher |> code() |> Sourceror.patch_string([patch])

    %__MODULE__{patcher | code: updated_code, result: :patched}
  end

  def code(%__MODULE__{code: code}) do
    code
  end

  defp build_keyword_node(key, value) do
    {:__block__, _, [[keyword]]} = Sourceror.parse_string!(~s([#{key}: #{value}]))
    keyword
  end

  defp to_string_opts() do
    {_formatter, opts} = Mix.Tasks.Format.formatter_for_file("mix.exs")
    Keyword.take(opts, [:line_length])
  end

  defp get_code_by_range(code, range) do
    {_, text_after} = split_at(code, range.start[:line], range.start[:column])
    line = range.end[:line] - range.start[:line] + 1
    {text, _} = split_at(text_after, line, range.end[:column])
    text
  end

  defp split_at(code, line, col) do
    pos = find_position(code, line, col, {0, 1, 1})
    String.split_at(code, pos)
  end

  defp find_position(_text, line, col, {pos, line, col}) do
    pos
  end

  defp find_position(text, line, col, {pos, current_line, current_col}) do
    case String.next_grapheme(text) do
      {grapheme, rest} ->
        {new_pos, new_line, new_col} =
          if grapheme in @line_break do
            if current_line == line do
              # this is the line we're lookin for
              # but it's shorter than expected
              {pos, current_line, col}
            else
              {pos + 1, current_line + 1, 1}
            end
          else
            {pos + 1, current_line, current_col + 1}
          end

        find_position(rest, line, col, {new_pos, new_line, new_col})

      nil ->
        pos
    end
  end

  defp add_indentation(code, n_spaces) do
    code
    |> String.split("\n")
    |> Enum.map(fn line ->
      if String.trim(line) == "" do
        ""
      else
        String.duplicate(" ", n_spaces) <> line
      end
    end)
    |> Enum.join("\n")
  end

  # TODO: use this when opts is properly retrieved
  # defp format_code!(code, indentation) do
  #   opts = "mix.exs" |> Mix.Tasks.Format.formatter_opts_for_file()
  #   opts = Keyword.update(opts, :line_length, 98, &(&1 - indentation))
  #   formatted_code = Code.format_string!(code, opts) |> to_string()
  #   add_indentation(formatted_code, indentation)
  # end
end
