defmodule PyroManiac.Form.Input do
  @moduledoc """
  A form input with an app input type: a module that implements
  `PyroManiac.Form.InputType`, with options.

      input :description, {BreweryWeb.Inputs.Markdown, toolbar: :minimal}
      input :notes, BreweryWeb.Inputs.Markdown
  """
  @moduledoc group: "PyroManiac"

  alias PyroManiac.Form.CommonInput

  use PyroManiac.Dsl.Entity,
    name: :input,
    args: [:name, :type],
    describe: "A form input with an app input type.",
    imports: [Ash.Expr],
    entities: [description: [PyroManiac.Description], render: [PyroManiac.Render]],
    schema:
      CommonInput.schema() ++
        [
          type: [
            doc:
              "The input type: a module that implements `PyroManiac.Form.InputType`, or `{module, options}`.",
            required: true,
            type: {:spark_behaviour, PyroManiac.Form.InputType}
          ]
        ],
    private_fields:
      CommonInput.private_fields() ++
        [
          __opts__: [
            default: [],
            doc:
              "The options of the input type, validated against its schema. Set by the transformer.",
            type: :keyword_list
          ]
        ]
end
