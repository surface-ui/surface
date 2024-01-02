defmodule Surface.Catalogue.DataTest do
  use ExUnit.Case

  alias Surface.Catalogue.Data
  require Data

  describe "accessors" do
    test "[key: key] - map or keyword's key" do
      map = %{0 => "zero", 1 => "one"}
      assert Data.get(map[[key: 0]]) == "zero"
    end

    test "[index: index] - list's index" do
      list = [:a, :b, :c]
      assert Data.get(list[[index: 2]]) == :c
    end

    test "[index] - list's index (shorthand syntax)" do
      list = [:a, :b, :c]
      assert Data.get(list[2]) == :c
    end

    test "[first..last] - list's range" do
      list = [:a, :b, :c, :d, :e]
      assert Data.get(list[1..-2//1]) == [:b, :c, :d]
    end

    test "[_] - list's all items" do
      list = [%{value: 1}, %{value: 2}, %{value: 3}]
      assert Data.get(list[_].value) == [1, 2, 3]
    end

    test "[fun] - filter list" do
      list = [1, 2, 3, 4, 5, 6]
      assert Data.get(list[&(rem(&1, 2) == 0)]) == [2, 4, 6]
    end
  end

  test "get" do
    map = %{lists: [%{id: "List_1"}, %{id: "List_2"}]}
    assert Data.get(map.lists[&(&1.id == "List_1")].id) == ["List_1"]
  end

  test "insert_at" do
    map = %{lists: [[], [:b, :c]]}
    assert Data.insert_at(map.lists[1], 0, :a) == %{lists: [[], [:a, :b, :c]]}
    assert Data.insert_at(map.lists[1], -1, :d) == %{lists: [[], [:b, :c, :d]]}
  end

  test "append" do
    map = %{lists: [[], [:b, :c]]}
    assert Data.append(map.lists[1], :d) == %{lists: [[], [:b, :c, :d]]}
  end

  test "prepend" do
    map = %{lists: [[], [:b, :c]]}
    assert Data.prepend(map.lists[1], :a) == %{lists: [[], [:a, :b, :c]]}
  end

  test "delete" do
    map = %{lists: [%{id: "List_1"}, %{id: "List_2"}]}
    assert Data.delete(map.lists[&(&1.id == "List_2")]) == %{lists: [%{id: "List_1"}]}
  end

  test "pop" do
    map = %{lists: [%{id: "List_1"}, %{id: "List_2"}]}

    assert Data.pop(map.lists[&(&1.id == "List_2")]) ==
             {[%{id: "List_2"}], %{lists: [%{id: "List_1"}]}}
  end

  test "update" do
    map = %{lists: [%{value: 2}, %{value: 3}]}

    assert Data.update(map.lists[_].value, fn v -> v * v end) == %{
             lists: [%{value: 4}, %{value: 9}]
           }
  end

  test "get_and_update" do
    map = %{lists: [%{value: 2}, %{value: 3}]}

    assert Data.get_and_update(map.lists[1].value, &{&1, &1 * &1}) ==
             {3, %{lists: [%{value: 2}, %{value: 9}]}}
  end

  describe "ranges" do
    setup do
      lists = [
        %{
          id: "List_1",
          cards: [
            %{id: "Card_1", text: "Fix bug #1"},
            %{id: "Card_2", text: "Fix bug #2"},
            %{id: "Card_3", text: "Fix bug #3"},
            %{id: "Card_4", text: "Fix bug #4"}
          ]
        },
        %{
          id: "List_2",
          cards: [
            %{id: "Card_5", text: "Fix bug #5"},
            %{id: "Card_6", text: "Fix bug #6"},
            %{id: "Card_7", text: "Fix bug #7"},
            %{id: "Card_8", text: "Fix bug #8"}
          ]
        }
      ]

      %{lists: lists}
    end

    test "get", %{lists: lists} do
      [cards_1, cards_2] = Data.get(lists[_].cards[1..2])

      assert [%{id: "Card_2"}, %{id: "Card_3"}] = cards_1
      assert [%{id: "Card_6"}, %{id: "Card_7"}] = cards_2
    end

    test "get! returns a single value", %{lists: lists} do
      assert %{text: "Fix bug #6"} = Data.get!(lists[_].cards[&(&1.id == "Card_6")])
    end

    test "get! raises if no value is found", %{lists: lists} do
      assert_raise(RuntimeError, "no value found", fn ->
        Data.get!(lists[_].cards[&(&1.id == "unknown")])
      end)
    end

    test "get! raises if more than one value is found", %{lists: lists} do
      assert_raise(RuntimeError, "more than one value found", fn ->
        Data.get!(lists[_].cards[&(&1.id =~ ~r/Card/)])
      end)
    end

    test "get with negative end index", %{lists: lists} do
      [cards_1, cards_2] = Data.get(lists[_].cards[1..-2//1])

      assert [%{id: "Card_2"}, %{id: "Card_3"}] = cards_1
      assert [%{id: "Card_6"}, %{id: "Card_7"}] = cards_2

      [cards_1, cards_2] = Data.get(lists[_].cards[0..-3//1])

      assert [%{id: "Card_1"}, %{id: "Card_2"}] = cards_1
      assert [%{id: "Card_5"}, %{id: "Card_6"}] = cards_2

      [cards_1, cards_2] = Data.get(lists[_].cards[2..-1//1])

      assert [%{id: "Card_3"}, %{id: "Card_4"}] = cards_1
      assert [%{id: "Card_7"}, %{id: "Card_8"}] = cards_2
    end

    test "update", %{lists: lists} do
      [%{cards: cards_1}, %{cards: cards_2}] =
        Data.update(lists[_].cards[1..2], &%{&1 | text: "#{&1.text} (updated)"})

      assert [
               %{id: "Card_1", text: "Fix bug #1"},
               %{id: "Card_2", text: "Fix bug #2 (updated)"},
               %{id: "Card_3", text: "Fix bug #3 (updated)"},
               %{id: "Card_4", text: "Fix bug #4"}
             ] = cards_1

      assert [
               %{id: "Card_5", text: "Fix bug #5"},
               %{id: "Card_6", text: "Fix bug #6 (updated)"},
               %{id: "Card_7", text: "Fix bug #7 (updated)"},
               %{id: "Card_8", text: "Fix bug #8"}
             ] = cards_2
    end

    test "get_and_update", %{lists: lists} do
      {[cards_1, cards_2], [%{cards: updated_cards_1}, %{cards: updated_cards_2}]} =
        Data.get_and_update(lists[_].cards[1..2], &{&1, %{&1 | text: "#{&1.text} (updated)"}})

      assert cards_1 == Enum.at(lists, 0).cards |> Enum.slice(1..2)
      assert cards_2 == Enum.at(lists, 1).cards |> Enum.slice(1..2)

      assert [
               %{id: "Card_1", text: "Fix bug #1"},
               %{id: "Card_2", text: "Fix bug #2 (updated)"},
               %{id: "Card_3", text: "Fix bug #3 (updated)"},
               %{id: "Card_4", text: "Fix bug #4"}
             ] = updated_cards_1

      assert [
               %{id: "Card_5", text: "Fix bug #5"},
               %{id: "Card_6", text: "Fix bug #6 (updated)"},
               %{id: "Card_7", text: "Fix bug #7 (updated)"},
               %{id: "Card_8", text: "Fix bug #8"}
             ] = updated_cards_2
    end
  end
end
