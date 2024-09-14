defmodule Surface.Catalogue.Data do
  @moduledoc """
  Experimental module that provides conveniences for manipulating data
  in Examples and Playgrounds.

  Provide wrappers around built-in functions like `get_in/2` and `update_in/3`
  using a shorter syntax for accessors.

  ## Accessor Mapping

    * `[_]`: `Access.all/0`
    * `[fun]`: `Access.filter(fun)`
    * `[index]`: `Access.at(index)` (Shorthand for `[index: i]`)
    * `[index: i]`: `Access.at(i)`
    * `[key: k]`: `Access.key(k)`
    * `[first..last]`: `Surface.Catalogue.Data.slice(first..last)`

  ## Example

      Data.get(props.lists[_].cards[& &1.id == "Card_1"].tags[-1].name)

  The code above will be translated to:

      get_in(props, [:lists, Access.all, :cards, Access.filter(& &1.id == "Card_1"), :tags, Access.at(-1), :name])

  """

  @doc """
  Generates a short ramdom id.
  """
  def random_id(size \\ 6) do
    :crypto.strong_rand_bytes(size)
    |> Base.encode32(case: :lower)
    |> binary_part(0, size)
  end

  @doc """
  Gets an existing value from the given nested structure.

  Raises an error if none or more than one value is found.
  """
  defmacro get!(path) do
    {subject, selector} = split_path(path)

    quote do
      unquote(__MODULE__).__get__!(unquote(subject), unquote(selector))
    end
  end

  @doc """
  Gets a value from the given nested structure.

  A wrapper around `get_in/2`
  """
  defmacro get(path) do
    {subject, selector} = split_path(path)

    quote do
      get_in(unquote(subject), unquote(selector))
    end
  end

  @doc """
  Gets a value and updates a given nested structure.

  A wrapper around `get_and_update_in/3`
  """
  defmacro get_and_update(path, fun) do
    {subject, selector} = split_path(path)

    quote do
      get_and_update_in(unquote(subject), unquote(selector), unquote(fun))
    end
  end

  @doc """
  Pops a item from the given nested structure.

  A wrapper around `pop_in/2`
  """
  defmacro pop(path) do
    {subject, selector} = split_path(path)

    quote do
      pop_in(unquote(subject), unquote(selector))
    end
  end

  @doc """
  Updates an item in the given nested structure.

  A wrapper around `update_in/2`
  """
  defmacro update(path, fun) do
    {subject, selector} = split_path(path)

    quote do
      update_in(unquote(subject), unquote(selector), unquote(fun))
    end
  end

  @doc """
  Deletes an item from the given nested structure.
  """
  defmacro delete(path) do
    {subject, selector} = split_path(path)

    quote do
      unquote(__MODULE__).__delete__(unquote(subject), unquote(selector))
    end
  end

  @doc """
  Inserts an item into a list in the given nested structure.
  """
  defmacro insert_at(path, pos, value) do
    {subject, selector} = split_path(path)

    quote do
      unquote(__MODULE__).__insert_at__(
        unquote(subject),
        unquote(selector),
        unquote(pos),
        unquote(value)
      )
    end
  end

  @doc """
  Appends an item to a list in the given nested structure.
  """
  defmacro append(path, value) do
    {subject, selector} = split_path(path)

    quote do
      unquote(__MODULE__).__insert_at__(unquote(subject), unquote(selector), -1, unquote(value))
    end
  end

  @doc """
  Prepends an item to a list in the given nested structure.
  """
  defmacro prepend(path, value) do
    {subject, selector} = split_path(path)

    quote do
      unquote(__MODULE__).__insert_at__(unquote(subject), unquote(selector), 0, unquote(value))
    end
  end

  @doc false
  def __get__!(subject, selector) do
    case get_in(subject, selector) |> List.flatten() do
      [item] ->
        item

      [] ->
        raise "no value found"

      [_ | _] ->
        raise "more than one value found"
    end
  end

  @doc false
  def __insert_at__(subject, selector, pos, value) do
    update_in(subject, selector, fn list ->
      List.insert_at(list, pos, value)
    end)
  end

  @doc false
  def __delete__(subject, selector) do
    {_, list} = pop_in(subject, selector)
    list
  end

  @doc false
  def access_fun(value) when is_function(value) do
    Access.filter(value)
  end

  def access_fun(value) when is_integer(value) do
    Access.at(value)
  end

  def access_fun(from..to//1 = range) when is_integer(from) and is_integer(to) do
    slice(range)
  end

  def access_fun(value) do
    Access.key(value)
  end

  defp quoted_access_fun({:_, _, _}) do
    quote do
      Access.all()
    end
  end

  defp quoted_access_fun(key: value) do
    quote do
      Access.key(unquote(value))
    end
  end

  defp quoted_access_fun(index: value) do
    quote do
      Access.at(unquote(value))
    end
  end

  defp quoted_access_fun(value) do
    quote do
      unquote(__MODULE__).access_fun(unquote(value))
    end
  end

  def slice(range) do
    fn op, data, next -> slice(op, data, range, next) end
  end

  defp slice(:get, data, range, next) when is_list(data) do
    data |> Enum.slice(range) |> Enum.map(next)
  end

  defp slice(:get_and_update, data, range, next) when is_list(data) do
    get_and_update_slice(data, range, next, [], [], -1)
  end

  defp slice(_op, data, _range, _next) do
    raise "slice expected a list, got: #{inspect(data)}"
  end

  defp normalize_range_bound(value, list_length) do
    if value < 0 do
      value + list_length
    else
      value
    end
  end

  defp get_and_update_slice([], _range, _next, updates, gets, _index) do
    {:lists.reverse(gets), :lists.reverse(updates)}
  end

  defp get_and_update_slice(list, from..to//1, next, updates, gets, -1) do
    list_length = length(list)
    from = normalize_range_bound(from, list_length)
    to = normalize_range_bound(to, list_length)
    get_and_update_slice(list, from..to, next, updates, gets, 0)
  end

  defp get_and_update_slice([head | rest], from..to//1 = range, next, updates, gets, index) do
    new_index = index + 1

    if index >= from and index <= to do
      case next.(head) do
        {get, update} ->
          get_and_update_slice(rest, range, next, [update | updates], [get | gets], new_index)

        :pop ->
          get_and_update_slice(rest, range, next, updates, [head | gets], new_index)
      end
    else
      get_and_update_slice(rest, range, next, [head | updates], gets, new_index)
    end
  end

  defp split_path(path) do
    {[subject | rest], _} = unnest(path, [], true, "test")
    {subject, convert_selector(rest)}
  end

  defp convert_selector(list) do
    Enum.map(list, fn
      {:map, key} ->
        quote do
          Access.key!(unquote(key))
        end

      {:access, expr} ->
        quoted_access_fun(expr)
    end)
  end

  def unnest(path) do
    unnest(path, [], true, "test")
  end

  defp unnest({{:., _, [Access, :get]}, _, [expr, key]}, acc, _all_map?, kind) do
    unnest(expr, [{:access, key} | acc], false, kind)
  end

  defp unnest({{:., _, [expr, key]}, _, []}, acc, all_map?, kind)
       when is_tuple(expr) and :erlang.element(1, expr) != :__aliases__ and
              :erlang.element(1, expr) != :__MODULE__ do
    unnest(expr, [{:map, key} | acc], all_map?, kind)
  end

  defp unnest(other, [], _all_map?, kind) do
    raise ArgumentError,
          "expected expression given to #{kind} to access at least one element, " <>
            "got: #{Macro.to_string(other)}"
  end

  defp unnest(other, acc, all_map?, kind) do
    case proper_start?(other) do
      true ->
        {[other | acc], all_map?}

      false ->
        raise ArgumentError,
              "expression given to #{kind} must start with a variable, local or remote call " <>
                "and be followed by an element access, got: #{Macro.to_string(other)}"
    end
  end

  defp proper_start?({{:., _, [expr, _]}, _, _args})
       when is_atom(expr)
       when :erlang.element(1, expr) == :__aliases__
       when :erlang.element(1, expr) == :__MODULE__,
       do: true

  defp proper_start?({atom, _, _args})
       when is_atom(atom),
       do: true

  defp proper_start?(other), do: not is_tuple(other)
end
