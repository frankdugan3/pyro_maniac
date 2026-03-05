defmodule PyroManiac.Page.TenantFrom do
  @moduledoc """
  Configures multi-tenancy for a PyroManiac page.

  ## Modes

  - `:scope` — Tenant is derived from the Ash scope (e.g. set by a plug or hook). No UI selector is rendered.
  - `:select` — Renders a `<select>` dropdown in the toolbar populated by reading tenant records.
  - `:combobox` — Renders a searchable combobox in the toolbar (future enhancement, currently renders as select).

  """

  use PyroManiac.Dsl.Entity,
    name: :tenant_from,
    args: [:mode],
    singleton_entity_keys: [:tenant_from],
    describe: "Configure multi-tenancy for this page.",
    schema: [
      mode: [
        type: {:one_of, [:scope, :select, :combobox]},
        required: true,
        doc:
          "How the tenant is resolved. `:scope` reads from Ash scope, `:select`/`:combobox` render a UI selector."
      ],
      resource: [
        type: {:spark, Ash.Resource},
        doc: "The tenant resource to read from (required for `:select`/`:combobox` modes)."
      ],
      label_field: [
        type: :atom,
        doc:
          "The field on the tenant resource to use as the display label (required for `:select`/`:combobox` modes)."
      ],
      param: [
        type: :string,
        default: "tenant",
        doc: "The URL query parameter name for persisting the selected tenant."
      ],
      read_action: [
        type: :atom,
        doc:
          "The read action to use when loading tenant records. Defaults to the primary read action."
      ]
    ]
end
