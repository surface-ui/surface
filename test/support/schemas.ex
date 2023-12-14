defmodule Surface.Schemas do
  defmodule Parent do
    defmodule Child do
      use Ecto.Schema

      embedded_schema do
        field(:name, :string)
      end

      def changeset(cs_or_map, data), do: Ecto.Changeset.cast(cs_or_map, data, [:name])
    end

    use Ecto.Schema

    embedded_schema do
      embeds_many(:children, Child)
    end

    def changeset(cs_or_map \\ %__MODULE__{}, data),
      do:
        Ecto.Changeset.cast(cs_or_map, data, [])
        |> Ecto.Changeset.cast_embed(:children)
  end
end
