defmodule PyroManiac.Resource do
  @moduledoc """
  Spark DSL extension for Ash resources that exposes PyroManiac configuration.

  Adds a `pyro_maniac` section with:

  - `default_label`: the field that renderers show as the name of a record
    (`PyroManiac.Info.default_label/1`).
  - `expose`: the **surface** of the resource. Refer to
    `PyroManiac.Resource.Expose`. A PyroManiac page can use only the exposed
    actions and fields.
  - `realtime`: the realtime notifications of the resource, with
    `Ash.Notifier.PubSub`. Refer to [Realtime](#module-realtime).

  ## Usage

      defmodule MyApp.Brewery.Recipe do
        use Ash.Resource,
          extensions: [PyroManiac.Resource]

        pyro_maniac do
          default_label :name

          realtime do
            mode :auto
          end

          expose :read do
            loads [:name, :style]
            filter [:name]
            sort [:name]
          end

          expose [:create, :update]
        end
      end

  ## Realtime

  This extension adds the extension `Ash.Notifier.PubSub` to the resource, so
  the `pub_sub` section is available without `notifiers:`. A resource
  without a `realtime` section has no realtime in PyroManiac, and a view with
  `on_create`, `on_update`, or `on_destroy` on it does not compile.

  - `mode :validate` (the default): you write `notifiers:
    [Ash.Notifier.PubSub]` and the `pub_sub` section. A verifier checks that
    the notifier is present and that `module` and `prefix` are set.
  - `mode :auto`: a transformer adds the notifier, sets `module` and
    `prefix` (when `pub_sub` does not set them), and adds these
    publications, each with `except`:

        publish_all :create, ["*"]
        publish_all :update, ["*"]
        publish_all :destroy, ["*"]
        # with record_topics? true:
        publish_all :update, ["updated", [:id, nil]]
        publish_all :destroy, ["destroyed", [:id, nil]]

    The publications that you write in `pub_sub` stay.

  In both modes, a verifier checks that each exposed create, update, and
  destroy action that is not in `except` has a publication with a static
  topic. `PyroManiac.SubscriptionManager` subscribes only to static topics.

  The default `module` is `config :pyro_maniac, :realtime, module: ...`. The
  transformer reads it at compile time. A change to it does not recompile
  the resources.

  The default `prefix` is the module name without its first segment, in
  snake case, joined with `_`: `MyApp.Brewery.Recipe` gives
  `"brewery_recipe"`.

  ## Bulk notifications

  A bulk operation (`Ash.bulk_create/4`, `Ash.bulk_update/4`,
  `Ash.bulk_destroy/4`) sends one notification for each record. With the
  action in `bulk`, it sends one `PyroManiac.Realtime.Bulk` message for the
  operation, on `PyroManiac.Realtime.bulk_topic/1`, a short window after
  its last notification (refer to `PyroManiac.Realtime.BulkCoalescer`). A
  call of the action for one record still sends its record notification. An atom in `bulk` that is not an action is an event for
  `PyroManiac.Realtime.broadcast_bulk/3`, for a bulk change that Ash does
  not notify (for example a truncate).

      realtime do
        mode :auto
        bulk [:import, :truncate]
      end

  A view gets the message with `on_bulk` (`:reload` or `:notify`).

  - `:auto` mode adds `PyroManiac.Realtime.BulkNotifier` and the filter
    `&PyroManiac.Realtime.record_notification?/1` to its publications.
  - `:validate` mode: a verifier checks that the notifier is in
    `notifiers:`, and that each publication of a bulk action has the filter.

  An action cannot be in `bulk` and in `except`.
  """

  @realtime %Spark.Dsl.Section{
    describe: """
    The realtime notifications of the resource. Without this section, the
    resource has no realtime in PyroManiac.
    """,
    name: :realtime,
    schema: [
      mode: [
        type: {:one_of, [:validate, :auto]},
        default: :validate,
        doc: "`:validate` checks the `pub_sub` configuration that you write. `:auto` makes it."
      ],
      module: [
        type: :atom,
        doc:
          "The PubSub module (`:auto` mode). Defaults to `config :pyro_maniac, :realtime, module: ...`."
      ],
      prefix: [
        type: :string,
        doc:
          "The topic prefix (`:auto` mode). Defaults to the module name without its first segment, in snake case, joined with `_`."
      ],
      record_topics?: [
        type: :boolean,
        default: true,
        doc:
          "Also publish updates on `updated:<id>` and destroys on `destroyed:<id>` (`:auto` mode)."
      ],
      except: [
        type: {:list, :atom},
        default: [],
        doc: "The create, update, and destroy actions that send no notification."
      ],
      bulk: [
        type: {:list, :atom},
        default: [],
        doc:
          "The actions whose bulk operations send one `PyroManiac.Realtime.Bulk` message in place of the record notifications, and the events of `PyroManiac.Realtime.broadcast_bulk/3` (for example `:truncate`). Refer to [Bulk notifications](#module-bulk-notifications)."
      ]
    ]
  }

  use Spark.Dsl.Extension,
    sections: [
      %Spark.Dsl.Section{
        describe: "Configure PyroManiac options for this resource.",
        name: :pyro_maniac,
        entities: [PyroManiac.Resource.Expose.__entity__()],
        sections: [@realtime],
        schema: [
          default_label: [
            type: :atom,
            required: true,
            doc:
              "The field (attribute, calculation, or aggregate) to use as the display label for records."
          ]
        ]
      }
    ],
    add_extensions: [Ash.Notifier.PubSub],
    transformers: [PyroManiac.Resource.Transformers.SetupRealtime],
    persisters: [PyroManiac.Resource.Persisters.ExpandExpose],
    verifiers: [
      PyroManiac.Resource.Verifiers.ValidateDefaultLabel,
      PyroManiac.Resource.Verifiers.VerifyExpose,
      PyroManiac.Resource.Verifiers.VerifyRealtime
    ]
end
