Code.put_compiler_option(:debug_info, true)

defmodule PyroManiac.DslErrors.FormsTest do
  @moduledoc false
  use ExUnit.Case, async: false

  import PyroManiac.Test.DslError

  describe "action lookup" do
    test "action not found in resource (with did-you-mean)" do
      expected = """
      [PyroManiac.DslErrors.FormsTest.UnknownAction]
      forms -> action -> craete defined in <FILE:LINE>:
        action :craete not found in resource Brewery.Recipe

        Did you mean:
          * :create
          * :retire
      │
      <LINE> │             action :craete do
      │             ~~~~~~~~~~~~~~~~~
      │
      └─ <FILE:LINE>: (file)\
      """

      assert_dsl_error expected do
        defmodule UnknownAction do
          use PyroManiac, resource: Brewery.Recipe

          forms do
            exclude([:create, :update, :activate, :retire])

            action :craete do
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
      end
    end

    test "action wrong type" do
      expected = """
      [PyroManiac.DslErrors.FormsTest.WrongActionType]
      forms -> action -> read defined in <FILE:LINE>:
        action :read is an unsupported type: :read

        Fix: form actions must reference a create or update action; pick a different action
      │
      <LINE> │             action :read do
      │             ~~~~~~~~~~~~~~~
      │
      └─ <FILE:LINE>: (file)\
      """

      assert_dsl_error expected do
        defmodule WrongActionType do
          use PyroManiac, resource: Brewery.Recipe

          forms do
            exclude([:create, :update, :activate, :retire])

            action :read do
              field :name, autofocus: true
            end
          end
        end
      end
    end

    test "action listed in exclude" do
      expected = """
      [PyroManiac.DslErrors.FormsTest.ActionExcluded]
      forms -> action -> create defined in <FILE:LINE>:
        action :create is listed in exclude

        Fix: either remove :create from `exclude([...])`, or remove this `action :create` block
      │
      <LINE> │             action :create do
      │             ~~~~~~~~~~~~~~~~~
      │
      └─ <FILE:LINE>: (file)\
      """

      assert_dsl_error expected do
        defmodule ActionExcluded do
          use PyroManiac, resource: Brewery.Recipe

          forms do
            exclude([:create, :update, :activate, :retire])

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
      end
    end
  end

  describe "missing actions" do
    test "create/update actions not defined or excluded" do
      expected = """
      [PyroManiac.DslErrors.FormsTest.MissingActions]
      forms defined in <FILE:LINE>:
        the following :create/:update actions are not defined or excluded: [:update, :activate, :retire]

        Fix: either define `action` blocks for these actions, or add them to `exclude([...])`
      │
      <LINE> │           forms do
      │           ~~~~~~~~
      │
      └─ <FILE:LINE>: (file)\
      """

      assert_dsl_error expected do
        defmodule MissingActions do
          use PyroManiac, resource: Brewery.Recipe

          forms do
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
      end
    end
  end

  describe "duplicate actions" do
    test "duplicate action name" do
      expected = """
      [PyroManiac.DslErrors.FormsTest.DuplicateActionName]
      forms -> action -> create defined in <FILE:LINE>:
        action :create is already defined for this resource
      │
      <LINE> │             action :create do
      │             ~~~~~~~~~~~~~~~~~
      │
      └─ <FILE:LINE>: (file)\
      """

      assert_dsl_error expected do
        defmodule DuplicateActionName do
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
      end
    end
  end

  describe "step layout" do
    test "steps and bare fields are mutually exclusive" do
      expected = """
      [PyroManiac.DslErrors.FormsTest.StepsAndBare]
      forms -> action -> create defined in <FILE:LINE>:
        action must have either steps or bare fields/field_groups at the top level, not both

        Fix: wrap the bare fields in a `step` block, or remove the steps
      │
      <LINE> │             action :create do
      │             ~~~~~~~~~~~~~~~~~
      │
      └─ <FILE:LINE>: (file)\
      """

      assert_dsl_error expected do
        defmodule StepsAndBare do
          use PyroManiac, resource: Brewery.Recipe

          forms do
            exclude([:update, :activate, :retire])

            action :create do
              field :description
              field :target_abv
              field :target_og
              field :target_fg
              field :status

              step :info do
                field :name, autofocus: true
                field :style
              end
            end
          end
        end
      end
    end
  end

  describe "autofocus" do
    test "zero autofocus fields" do
      expected = """
      [PyroManiac.DslErrors.FormsTest.ZeroAutofocus]
      forms -> action -> create defined in <FILE:LINE>:
        exactly one field must have autofocus

        Fix: add `autofocus: true` to exactly one field in this action
      │
      <LINE> │             action :create do
      │             ~~~~~~~~~~~~~~~~~
      │
      └─ <FILE:LINE>: (file)\
      """

      assert_dsl_error expected do
        defmodule ZeroAutofocus do
          use PyroManiac, resource: Brewery.Recipe

          forms do
            exclude([:update, :activate, :retire])

            action :create do
              field :name
              field :style
              field :description
              field :target_abv
              field :target_og
              field :target_fg
              field :status
            end
          end
        end
      end
    end

    test "two autofocus fields" do
      expected = """
      [PyroManiac.DslErrors.FormsTest.TwoAutofocus]
      forms -> action -> create defined in <FILE:LINE>:
        exactly one field must have autofocus

        Fix: add `autofocus: true` to exactly one field in this action
      │
      <LINE> │             action :create do
      │             ~~~~~~~~~~~~~~~~~
      │
      └─ <FILE:LINE>: (file)\
      """

      assert_dsl_error expected do
        defmodule TwoAutofocus do
          use PyroManiac, resource: Brewery.Recipe

          forms do
            exclude([:update, :activate, :retire])

            action :create do
              field :name, autofocus: true
              field :style, autofocus: true
              field :description
              field :target_abv
              field :target_og
              field :target_fg
              field :status
            end
          end
        end
      end
    end
  end

  describe "duplicate fields" do
    test "duplicate field name" do
      expected = """
      [PyroManiac.DslErrors.FormsTest.DuplicateFieldName]
      forms -> action -> create defined in <FILE:LINE>:
        field :style is already defined
      │
      <LINE> │               field :style
      │               ~~~~~~~~~~~~
      │
      └─ <FILE:LINE>: (file)\
      """

      assert_dsl_error expected do
        defmodule DuplicateFieldName do
          use PyroManiac, resource: Brewery.Recipe

          forms do
            exclude([:update, :activate, :retire])

            action :create do
              field :name, autofocus: true
              field :style
              field :style, label: "Style 2"
              field :description
              field :target_abv
              field :target_og
              field :target_fg
              field :status
            end
          end
        end
      end
    end

    test "duplicate field label" do
      expected = """
      [PyroManiac.DslErrors.FormsTest.DuplicateFieldLabel]
      forms -> action -> create defined in <FILE:LINE>:
        another field already uses the label "Name"
      │
      <LINE> │               field :name, autofocus: true
      │               ~~~~~~~~~~~~~~~~~~~~~~~~~~~~
      │
      └─ <FILE:LINE>: (file)\
      """

      assert_dsl_error expected do
        defmodule DuplicateFieldLabel do
          use PyroManiac, resource: Brewery.Recipe

          forms do
            exclude([:update, :activate, :retire])

            action :create do
              field :name, autofocus: true
              field :style, label: "Name"
              field :description
              field :target_abv
              field :target_og
              field :target_fg
              field :status
            end
          end
        end
      end
    end
  end

  describe "field/action coverage" do
    test "field not in accepts/arguments (with did-you-mean)" do
      expected = """
      [PyroManiac.DslErrors.FormsTest.UnknownField]
      forms -> action -> create -> field -> nam defined in <FILE:LINE>:
        field :nam is not an accepted attribute or argument for this action

        Did you mean:
          * :name
      │
      <LINE> │               field :nam, autofocus: true
      │               ~~~~~~~~~~~~~~~~~~~~~~~~~~~
      │
      └─ <FILE:LINE>: (file)\
      """

      assert_dsl_error expected do
        defmodule UnknownField do
          use PyroManiac, resource: Brewery.Recipe

          forms do
            exclude([:update, :activate, :retire])

            action :create do
              field :nam, autofocus: true
              field :style
              field :description
              field :target_abv
              field :target_og
              field :target_fg
              field :status
            end
          end
        end
      end
    end

    test "accepted attribute missing as form field" do
      expected = """
      [PyroManiac.DslErrors.FormsTest.MissingAccept]
      forms -> action -> create defined in <FILE:LINE>:
        accepted attribute :description is not a form field

        Fix: add `field :description` to this action, exclude :description from the action's `accept` list, or add it as a `set`
      │
      <LINE> │             action :create do
      │             ~~~~~~~~~~~~~~~~~
      │
      └─ <FILE:LINE>: (file)\
      """

      assert_dsl_error expected do
        defmodule MissingAccept do
          use PyroManiac, resource: Brewery.Recipe

          forms do
            exclude([:update, :activate, :retire])

            action :create do
              field :name, autofocus: true
              field :style
            end
          end
        end
      end
    end

    test "unknown field type with did-you-mean" do
      expected = """
      [PyroManiac.DslErrors.FormsTest.UnknownFieldType]
      forms -> field -> target_abv -> type defined in <FILE:LINE>:
        unknown field type :tex for field :target_abv. Accepted types: [:attachment, :boolean, :checkbox, :combobox, :date, :datetime, :default, :email, :interval, :naive_datetime, :nested_form, :number, :password, :select, :text, :textarea, :time, :toggle]

        Did you mean:
          * :text
          * :textarea
      │
      <LINE> │               field :target_abv, type: :tex
      │               ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
      │
      └─ <FILE:LINE>: (file)\
      """

      assert_dsl_error expected do
        defmodule UnknownFieldType do
          use PyroManiac, resource: Brewery.Recipe

          forms do
            exclude([:update, :activate, :retire])

            action :create do
              field :name, autofocus: true
              field :style
              field :description
              field :target_abv, type: :tex
              field :target_og
              field :target_fg
              field :status
              field :photos, type: :attachment
            end
          end
        end
      end
    end

    test "argument missing as form field" do
      expected = """
      [PyroManiac.DslErrors.FormsTest.MissingArgument]
      forms -> action -> create defined in <FILE:LINE>:
        argument :recipe_id is not a form field

        Fix: add `field :recipe_id` to this action, or set it via `set`
      │
      <LINE> │             action :create do
      │             ~~~~~~~~~~~~~~~~~
      │
      └─ <FILE:LINE>: (file)\
      """

      assert_dsl_error expected do
        defmodule MissingArgument do
          use PyroManiac, resource: Brewery.Batch

          forms do
            exclude([
              :update,
              :start_brewing,
              :advance_status,
              :complete,
              :move_card
            ])

            action :create do
              field :batch_number, autofocus: true
              field :status
              field :brew_date
              field :package_date
              field :actual_og
              field :actual_fg
              field :actual_abv
              field :volume_liters
              field :notes
            end
          end
        end
      end
    end
  end
end
