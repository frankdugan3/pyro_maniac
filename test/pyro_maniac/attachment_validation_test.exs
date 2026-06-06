Code.put_compiler_option(:debug_info, true)

defmodule PyroManiac.AttachmentValidationTest do
  @moduledoc """
  The attachment upload field is required on a form action only when that action
  exposes an `Ash.Type.File` argument (single or list) — not for every AshStorage
  attachment on the resource. A `form_only?` field never satisfies the requirement.
  """
  use ExUnit.Case, async: false

  import PyroManiac.Test.DslError

  # Brewery.Recipe has a `has_many_attached :photos`, but `:create` exposes no
  # file argument. Pre-fix this raised; now the form can omit `field :photos`.
  defmodule NoFileArgumentPage do
    @moduledoc false
    use PyroManiac, resource: Brewery.Recipe

    forms do
      exclude([:update, :activate, :retire])

      action :create do
        field :name, autofocus: true
        field :style
        field :description
        field :target_abv
        field :target_og
        field :target_fg
        field :status
      end
    end
  end

  # Brewery.QualityTest `:archive` exposes `argument :lab_reports, {:array,
  # Ash.Type.File}` and the form declares the matching attachment field.
  defmodule FileArgumentPage do
    @moduledoc false
    use PyroManiac, resource: Brewery.QualityTest

    forms do
      exclude([:create, :update])

      action :archive do
        field :lab_reports, type: :attachment, autofocus: true
      end
    end
  end

  test "action without a file argument does not require an attachment field" do
    assert Brewery.Recipe == NoFileArgumentPage.persisted(:resource, nil)

    field_names =
      NoFileArgumentPage
      |> PyroManiac.Info.form_for(:create)
      |> Map.get(:fields)
      |> Enum.map(& &1.name)

    refute :photos in field_names
  end

  test "action with a file argument accepts a matching attachment field" do
    assert Brewery.QualityTest == FileArgumentPage.persisted(:resource, nil)

    assert :lab_reports in (FileArgumentPage
                            |> PyroManiac.Info.form_for(:archive)
                            |> Map.get(:fields)
                            |> Enum.map(& &1.name))
  end

  test "a file argument surfaced as a non-attachment field is rejected" do
    assert_dsl_error ~r/action :archive has a file argument :lab_reports but this form does not declare a \(non-`form_only\?`\) `type: :attachment` field for it/ do
      defmodule WrongFieldTypePage do
        @moduledoc false
        use PyroManiac, resource: Brewery.QualityTest

        forms do
          exclude([:create, :update])

          action :archive do
            field :lab_reports, autofocus: true
          end
        end
      end
    end
  end
end
