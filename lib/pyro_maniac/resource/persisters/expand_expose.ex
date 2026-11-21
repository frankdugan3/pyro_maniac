defmodule PyroManiac.Resource.Persisters.ExpandExpose do
  @moduledoc false

  # Unrolls each `expose` with more than one action into one entity for each
  # action, and expands `:*`. A persister runs after all the transformers, so
  # the fields of the other extensions are present.
  #
  # - An option that is not set is `[:*]` (`filter` and `sort`: only for a
  #   read action, else `[]`). To opt out, set `[]`.
  # - `:*` in a field list: the public attributes, calculations, and
  #   aggregates of the resource (for `filter` and `sort`, only the fields
  #   that Ash can filter and sort: `PyroManiac.Resource.Info.public_fields/2`).
  #
  # The relationships (`:owner`, and `:*` in `owner: [...]`) stay as they
  # are: `PyroManiac.Resource.Info.exposed/1` expands them, because they need
  # the fields of other resources.

  use Spark.Dsl.Transformer

  alias PyroManiac.Resource.Expose
  alias Spark.Dsl.Transformer

  @impl true
  def transform(dsl) do
    fields = %{
      loads: PyroManiac.Resource.Info.public_fields(dsl, :loads),
      filter: PyroManiac.Resource.Info.public_fields(dsl, :filter),
      sort: PyroManiac.Resource.Info.public_fields(dsl, :sort)
    }

    exposes =
      for %Expose{name: names} = expose <- Transformer.get_entities(dsl, [:pyro_maniac]),
          name <- List.wrap(names) do
        expand(%{expose | name: name}, dsl, fields)
      end

    dsl = Transformer.remove_entity(dsl, [:pyro_maniac], &match?(%Expose{}, &1))

    dsl =
      exposes
      |> Enum.reverse()
      |> Enum.reduce(dsl, &Transformer.add_entity(&2, [:pyro_maniac], &1))

    {:ok, dsl}
  end

  defp expand(expose, dsl, fields) do
    read? = match?(%{type: :read}, Ash.Resource.Info.action(dsl, expose.name))

    %{
      expose
      | loads: resolve(expose.loads, fields.loads, true),
        filter: resolve(expose.filter, fields.filter, read?),
        sort: resolve(expose.sort, fields.sort, read?)
    }
  end

  defp resolve(nil, fields, true), do: fields
  defp resolve(nil, _fields, false), do: []

  defp resolve(list, fields, _default?) do
    list
    |> List.wrap()
    |> Enum.flat_map(fn
      :* -> fields
      item -> [item]
    end)
    |> Enum.uniq()
  end
end
