defmodule PyroManiac.Resource.Expose do
  @moduledoc """
  One action of the surface of a resource: the action that a UI can run, and
  the fields that the UI can load, filter on, and sort on.

  The surface is the complete list of what a PyroManiac page can use. A page
  that uses an action or a field that is not exposed does not compile.

  ```elixir
  pyro_maniac do
    default_label :name

    expose :read do
      loads [:name, :style, recipe_ingredients: [:quantity]]
      filter [:name, :style]
      sort [:name]
    end

    expose [:create, :update] do
      loads [:name]
    end

    expose :activate
  end
  ```

  `loads`, `filter`, and `sort` are field lists. An item is:

  - `:*`: all the public attributes, calculations, and aggregates of the
    resource (not its relationships). In `filter`, `:*` has no field with
    `filterable? false`; in `sort`, no field with `sortable? false` (Ash
    refuses them). Set these options on a field (for example a password)
    that no filter or sort may use.
  - A field: an attribute, a calculation, or an aggregate.
  - A relationship: `:batches` is the relationship with `:*` of its resource,
    one level deep (the same as `batches: [:*]`).
  - A relationship with a field list: `recipe_ingredients: [:quantity, ingredient: [:name]]`. A
    deeper load is always explicit.

  All the fields and relationships must be public.

  ```elixir
  expose :read do
    loads [:*, :batches, recipe_ingredients: [:quantity]]
    sort [:name]
  end
  ```

  Each option defaults to `[:*]` (`filter` and `sort` only for a read action).
  To opt out of one, set it:

  ```elixir
  # loads, filter, and sort: all the fields
  expose :read

  # loads: all the fields
  expose [:create, :update]

  # loads [:name], filter all the fields, no sort
  expose :list do
    loads [:name]
    sort []
  end
  ```

  The Ash actions and fields are explicit about `public?`, so `:*` exposes
  only what the resource already makes public.

  A persister unrolls an `expose` with more than one action into one entity
  for each action, applies the defaults, and expands the `:*` of the
  resource, after all the transformers (thus also the fields that other
  extensions add). `PyroManiac.Resource.Info.exposed/1` also expands the
  relationships (`:batches`, and `:*` in `batches: [...]`): that needs the fields
  of other resources, which a resource cannot read while it compiles (two
  related resources would wait for each other).
  """
  @moduledoc group: "PyroManiac"

  @field_list {:wrap_list, {:or, [:atom, {:tuple, [:atom, :any]}]}}

  use PyroManiac.Dsl.Entity,
    name: :expose,
    args: [:name],
    describe: "Expose one or more actions of the resource to the UI.",
    schema: [
      name: [
        doc:
          "The action names. Each action in the list gets the same options. After the persister, one action name.",
        required: true,
        type: {:wrap_list, :atom}
      ],
      loads: [
        doc: "The fields that a UI can load. Defaults to `[:*]`; `[]` for none.",
        type: @field_list
      ],
      filter: [
        doc:
          "The fields that a UI can filter on. Read actions only. Defaults to `[:*]` for a read action; `[]` for none.",
        type: @field_list
      ],
      sort: [
        doc:
          "The fields that a UI can sort on. Read actions only. Defaults to `[:*]` for a read action; `[]` for none.",
        type: @field_list
      ]
    ]
end
