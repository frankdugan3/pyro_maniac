defmodule PyroManiac.View.View do
  @moduledoc """
  A unified view configuration in `PyroManiac`.

  Views are the primary display primitive. Each view maps to a read action
  on an Ash resource and renders records using a specific view type.

  ## View Types

  - `:data_table` — Paginated, sortable, filterable table with interactive columns
  - `:grid` — Card grid layout with sections, fields, and relationships
  - `:calendar` — Calendar/timeline view keyed on date fields
  - `:gantt` — Gantt chart for scheduling data with start/end dates
  - `:kanban` — Board with swimlanes grouped by a field
  - `:list` — Tree/outline list, optionally hierarchical
  - `:render` — Custom render function (escape hatch)
  - `:delegated` — Mount a full autonomous sub-Viewer from another PyroManiac module

  Views can be recursively nested to drill down into relationships or
  cross-resource data.

  ## Example

      views do
        view :read do
          type :data_table
          column :name
          column :status

          view do
            type :delegated
            relationship :ingredients
            delegate_to Some.IngredientViews
          end
        end
      end
  """

  use PyroManiac.Dsl.Entity,
    name: :view,
    args: [:name],
    describe: "Declare a view for displaying resource data. Can be nested recursively.",
    recursive_as: :views,
    entities: [
      columns: [PyroManiac.View.Column],
      fields: [PyroManiac.View.Field],
      sections: [PyroManiac.View.Section],
      sets: [PyroManiac.View.Set],
      extra_actions: [PyroManiac.Page.ExtraAction],
      views: []
    ],
    schema: [
      name: [
        doc: "The action name(s) for this view. Required for all types except `:delegated`.",
        type: {:wrap_list, :atom},
        default: []
      ],
      type: [
        doc: "The view type.",
        required: true,
        type:
          {:one_of, [:data_table, :grid, :calendar, :gantt, :kanban, :list, :render, :delegated]}
      ],
      resource: [
        doc:
          "Target resource. Defaults to the module's main resource, or the relationship destination when nested with `relationship`.",
        type: {:spark, Ash.Resource}
      ],
      relationship: [
        doc: "Which relationship to traverse (for nested views).",
        type: :atom
      ],
      label: [
        doc: "Display label for this view (defaults to capitalized name).",
        type: :string
      ],
      description: [
        doc: "Description text for this view.",
        type: PyroManiac.Dsl.Type.inheritable(:string)
      ],
      class: [
        doc: "Container CSS classes.",
        type: PyroManiac.Dsl.Type.css_class()
      ],
      default_page_size: [
        doc: "Default page size. Falls back to action's default_limit, then 25.",
        type: :pos_integer
      ],
      page_sizes: [
        doc: "Available page size options for pagination controls.",
        type: {:list, :pos_integer}
      ],
      default_sort: [
        doc: "Default sort specification.",
        type: PyroManiac.Dsl.Type.sort()
      ],
      pagination: [
        doc: "Pagination type. Auto-detected from resource action if not set.",
        type: PyroManiac.Dsl.Type.pagination()
      ],
      count?: [
        doc: "Display page count. Defaults to true for offset if allowed.",
        type: :boolean
      ],
      read_action: [
        doc: "Override which read action to use on the target resource.",
        type: :atom
      ],
      __arguments__: [
        private?: true,
        hide: true,
        default: [],
        doc: "Read action arguments as resolved fields. Set by the transformer.",
        type: {:list, :any}
      ],
      exclude: [
        default: [],
        doc: "Fields to exclude from this view.",
        type: {:list, :atom}
      ],
      ensure_loaded: [
        default: [],
        doc:
          "Ash load statement always applied when loading data for this view, " <>
            "in addition to the loads inferred from columns, fields, and sections.",
        type: PyroManiac.Dsl.Type.load()
      ],
      on_create: [
        doc: "How to handle PubSub create notifications.",
        type: PyroManiac.Dsl.Type.on_create()
      ],
      on_update: [
        doc: "How to handle PubSub update notifications.",
        type: PyroManiac.Dsl.Type.on_update()
      ],
      on_destroy: [
        doc: "How to handle PubSub destroy notifications.",
        type: PyroManiac.Dsl.Type.on_destroy()
      ],
      lazy?: [
        default: true,
        doc: "Load nested view data only when the row is expanded.",
        type: :boolean
      ],
      multiple?: [
        default: false,
        doc: "Allow multiple rows to be expanded simultaneously. When false, acts as accordion.",
        type: :boolean
      ],
      selectable?: [
        default: true,
        doc: "Enable row selection for bulk actions (`:data_table` only).",
        type: :boolean
      ],
      default_display: [
        doc: "Which columns are visible by default (`:data_table` only).",
        type: {:list, :atom}
      ],
      body_class: [
        doc: "Data table tbody classes.",
        type: PyroManiac.Dsl.Type.css_class()
      ],
      body_row_class: [
        doc: "Data table tbody > tr classes.",
        type: PyroManiac.Dsl.Type.css_class()
      ],
      caption_class: [
        doc: "Data table caption classes.",
        type: PyroManiac.Dsl.Type.css_class()
      ],
      header_class: [
        doc: "Data table thead classes.",
        type: PyroManiac.Dsl.Type.css_class()
      ],
      header_row_class: [
        doc: "Data table thead > tr classes.",
        type: PyroManiac.Dsl.Type.css_class()
      ],
      footer_class: [
        doc: "Data table tfoot classes.",
        type: PyroManiac.Dsl.Type.css_class()
      ],
      footer_row_class: [
        doc: "Data table tfoot > tr classes.",
        type: PyroManiac.Dsl.Type.css_class()
      ],
      footer_cell_class: [
        doc: "Data table tfoot > tr > td classes.",
        type: PyroManiac.Dsl.Type.css_class()
      ],
      grid_class: [
        doc: "CSS grid container class (`:grid` only).",
        type: PyroManiac.Dsl.Type.css_class()
      ],
      group_by: [
        doc: "Field to group records into swimlanes (`:kanban` and optionally `:gantt`).",
        type: :atom
      ],
      lane_class: [
        doc: "Swimlane container CSS class (`:kanban` only).",
        type: PyroManiac.Dsl.Type.css_class()
      ],
      kanban_action: [
        doc:
          "Update action for kanban card moves (`:kanban` only). Must accept both the `group_by` and `priority` fields.",
        type: :atom
      ],
      priority: [
        doc:
          "Integer attribute for card ordering within lanes (`:kanban` only). Enables drag reordering. The attribute must be an integer type on the resource. Sets `default_sort` automatically.",
        type: :atom
      ],
      date_field: [
        doc: "Field for event date or start date (`:calendar` only).",
        type: :atom
      ],
      end_date_field: [
        doc: "Field for event end date (`:calendar` only, optional for ranges).",
        type: :atom
      ],
      granularity: [
        doc: "Calendar resolution (`:calendar` only).",
        type: {:one_of, [:day, :week, :month]}
      ],
      start_field: [
        doc: "Field for task start date (`:gantt` only).",
        type: :atom
      ],
      end_field: [
        doc: "Field for task end date (`:gantt` only).",
        type: :atom
      ],
      progress_field: [
        doc: "Field for completion percentage (`:gantt` only, optional).",
        type: :atom
      ],
      parent_field: [
        doc: "Self-referencing field for tree hierarchy (`:list` only, optional).",
        type: :atom
      ],
      indent_class: [
        doc: "Per-level indentation CSS class (`:list` only).",
        type: PyroManiac.Dsl.Type.css_class()
      ],
      render: [
        doc: "Custom render function (`:render` only). Receives assigns.",
        type: PyroManiac.Dsl.Type.render_fn()
      ],
      component: [
        doc: "LiveComponent module to embed (`:render` only, alternative to `render`).",
        type: :atom
      ],
      component_id_suffix: [
        doc: "Component ID suffix (`:render` only).",
        type: :string
      ],
      props: [
        doc: "Static props passed to the LiveComponent (`:render` only).",
        default: [],
        type: :keyword_list
      ],
      loads: [
        doc: "Ash load statement for `:render` views.",
        default: [],
        type: :any
      ],
      delegate_to: [
        doc:
          "For `:delegated` views, the PyroManiac module to mount as a full autonomous sub-Viewer. Required when `type` is `:delegated`, forbidden otherwise.",
        type: {:spark, PyroManiac}
      ]
    ],
    transform: {__MODULE__, :__set_defaults__, []}

  alias PyroManiac.Dsl.Transformers

  @view_types [:data_table, :grid, :calendar, :gantt, :kanban, :list, :render, :delegated]

  @doc false
  def __set_defaults__(view) do
    {:ok,
     view
     |> Map.update!(:label, fn
       nil when view.name == [] -> nil
       nil -> Transformers.default_label(hd(view.name))
       label -> label
     end)
     |> Map.update!(:on_create, fn
       nil -> :none
       v -> v
     end)
     |> Map.update!(:on_update, fn
       nil -> :none
       v -> v
     end)
     |> Map.update!(:on_destroy, fn
       nil -> :none
       v -> v
     end)}
  end

  @doc "Returns the list of valid view types."
  def view_types, do: @view_types
end
