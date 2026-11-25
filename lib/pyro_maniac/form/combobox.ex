defmodule PyroManiac.Form.Combobox do
  @moduledoc """
  A form input that searches for its value.

  The mode comes from the field:

  - **Select**: the field is the foreign key of a `belongs_to`. The user
    selects a record of the destination.
  - **Select many**: the field is an argument that the action passes to
    `manage_relationship` (for example of a `many_to_many`). The user
    selects the related records: attach and detach.
  - **Free text**: the field is a `:string` or `:ci_string`. The typed text
    is the value, and the options are the values that the records of the
    form resource already have.

  The search is declared here, not as an action of the resource. It uses
  the primary read action (or `read_action`), with `search`, `filter`,
  `sort`, and `limit`. Use `^search()` and `^input(:name)` (from
  `PyroManiac.Form.Templates`) in `filter`, which is an expression. An
  `argument` entity gives an input for an argument of `read_action`. Its
  value is not in an expression, so its templates have no `^`, as in
  `set_attribute(:status, arg(:status))` of Ash.

      combobox :lot_number do
        filter expr(is_nil(^input(:name)) or name == ^input(:name))
      end

      combobox :supplier_id do
        read_action :by_prefix
        argument :prefix, search()
        search false
      end
  """
  @moduledoc group: "PyroManiac"

  alias PyroManiac.Dsl.Type
  alias PyroManiac.Form.CommonInput

  use PyroManiac.Dsl.Entity,
    name: :combobox,
    args: [:name],
    describe: "A form input that searches for its value.",
    imports: [Ash.Expr, PyroManiac.Form.Templates],
    entities: [
      description: [PyroManiac.Description],
      arguments: [PyroManiac.Form.Combobox.Argument],
      link_to: [PyroManiac.LinkTo],
      render: [PyroManiac.Render]
    ],
    schema:
      CommonInput.schema() ++
        [
          read_action: [
            doc:
              "The read action of the searched resource. Defaults to its primary read action. Its own filter, preparations, and policies apply.",
            type: :atom
          ],
          search: [
            doc:
              "The fields that the typed text matches (`contains`, joined with `or`). Defaults to `[label_key]`. `false` when `filter` uses `^search()` or an `argument` uses `search()`.",
            type: {:or, [{:list, :atom}, {:literal, false}]}
          ],
          filter: [
            doc:
              "An additional filter (an Ash expression), joined with `and`. It can use `^search()`, `^input(:name)`, and `^actor(...)`.",
            type: Type.expression()
          ],
          sort: [
            doc: "The order of the options. Defaults to `[{label_key, :asc}]`.",
            type: :keyword_list
          ],
          limit: [
            default: 20,
            doc: "The maximum number of options, from 1 to 100.",
            type: :pos_integer
          ],
          label_key: [
            doc:
              "The text of an option. Select mode: defaults to the `default_label` of the destination. Free text: always `value_key`.",
            type: :atom
          ],
          value_key: [
            doc:
              "The value of an option. Select mode: defaults to the primary key of the destination. Free text: defaults to the name of the field.",
            type: :atom
          ]
        ],
    private_fields:
      CommonInput.private_fields() ++
        [
          __mode__: [
            doc: "`:select` or `:free_text`. Set by the transformer.",
            type: {:one_of, [:select, :free_text]}
          ],
          __resource__: [
            doc: "The searched resource. Set by the transformer.",
            type: :atom
          ],
          __relationship__: [
            doc:
              "Select mode: the relationship whose records the combobox selects (the `belongs_to` of the foreign key, or the relationship that the action manages with the argument), which view mode shows. Set by the transformer.",
            type: :atom
          ],
          "__multiple?__": [
            default: false,
            doc:
              "Whether the combobox selects many records: an argument that the action passes to `manage_relationship` of a relationship to many records (attach and detach). Set by the transformer.",
            type: :boolean
          ],
          __inputs__: [
            default: [],
            doc: "The inputs that `^input/1` names. Set by the transformer.",
            type: {:list, :atom}
          ]
        ]
end
