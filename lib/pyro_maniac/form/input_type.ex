defmodule PyroManiac.Form.InputType do
  @moduledoc """
  The behaviour of an app input type, for the `input` entity.

      input :body, {MyAppWeb.Inputs.Markdown, profile: :issue}

  The behaviour has no rendering, so that PyroManiac stays
  renderer-agnostic. Each renderer has its own render behaviour.
  """
  @moduledoc group: "PyroManiac"

  @doc "The Spark option schema of the options. Validated at compile time."
  @callback schema() :: Spark.Options.schema()

  @doc "The size for `size: :auto`."
  @callback default_size() :: :code | :term | :name | :phrase | :prose
end
