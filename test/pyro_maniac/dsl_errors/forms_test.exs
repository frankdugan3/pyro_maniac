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
              select :style
              field :description
              field :target_abv
              field :target_og
              field :target_fg
              select :status
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
              select :style
              field :description
              field :target_abv
              field :target_og
              field :target_fg
              select :status
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
              select :style
              field :description
              field :target_abv
              field :target_og
              field :target_fg
              select :status
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
              select :style
              field :description
              field :target_abv
              field :target_og
              field :target_fg
              select :status
            end

            action :create do
              field :name, autofocus: true
              select :style
              field :description
              field :target_abv
              field :target_og
              field :target_fg
              select :status
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
        action must have either steps or inputs and groups at the top level, not both

        Fix: wrap the other entities in a `step` block, or remove the steps
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
              select :status

              step :info do
                field :name, autofocus: true
                select :style
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
              select :style
              field :description
              field :target_abv
              field :target_og
              field :target_fg
              select :status
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
              select :style, autofocus: true
              field :description
              field :target_abv
              field :target_og
              field :target_fg
              select :status
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
      <LINE> │               select :style, label: "Style 2"
      │               ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
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
              select :style
              select :style, label: "Style 2"
              field :description
              field :target_abv
              field :target_og
              field :target_fg
              select :status
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
      <LINE> │               select :style, label: "Name"
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
              select :style, label: "Name"
              field :description
              field :target_abv
              field :target_og
              field :target_fg
              select :status
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
              select :style
              field :description
              field :target_abv
              field :target_og
              field :target_fg
              select :status
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
              select :style
            end
          end
        end
      end
    end

    test "unknown field type with did-you-mean" do
      expected = """
      [PyroManiac.DslErrors.FormsTest.UnknownFieldType]
      forms -> field -> target_abv -> type defined in <FILE:LINE>:
        unknown field type :tex for field :target_abv. Accepted types: [:attachment, :boolean, :checkbox, :date, :datetime, :default, :email, :interval, :naive_datetime, :nested_form, :number, :password, :search, :tel, :text, :textarea, :time, :toggle, :url]

        Did you mean:
          * :text
          * :textarea
          * :tel

        Fix: for an app input type, use `input :target_abv, MyInputType`
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
              select :style
              field :description
              field :target_abv, type: :tex
              field :target_og
              field :target_fg
              select :status
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
              select :status
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

  describe "input kind" do
    test "a field on a belongs_to foreign key recommends combobox" do
      assert_dsl_error ~r/field :recipe_id is the foreign key of the `belongs_to` :recipe, so its input is a combobox.*use `combobox :recipe_id` instead of `field :recipe_id`/s do
        defmodule FieldOnForeignKey do
          use PyroManiac, resource: Brewery.Batch

          forms do
            exclude([:update, :start_brewing, :advance_status, :complete, :move_card])

            action :create do
              field :batch_number, autofocus: true
              select :status
              field :brew_date
              field :package_date
              field :actual_og
              field :actual_fg
              field :actual_abv
              field :volume_liters
              field :notes
              field :recipe_id
              combobox :brewer_id
            end
          end
        end
      end
    end

    test "a field on a closed set of values recommends select" do
      assert_dsl_error ~r/field :status has a closed set of values, so its input is a select.*use `select :status` instead of `field :status`/s do
        defmodule FieldOnEnum do
          use PyroManiac, resource: Brewery.Recipe

          forms do
            exclude([:update, :activate, :retire])

            action :create do
              field :name, autofocus: true
              select :style
              field :description
              field :target_abv
              field :target_og
              field :target_fg
              field :status
              field :photos, type: :attachment
            end
          end
        end
      end
    end

    test "type :combobox on a field is not a field type" do
      assert_dsl_error ~r/`type: :combobox` is not a field type.*use `combobox :name` instead of `field :name`/s do
        defmodule ComboboxType do
          use PyroManiac, resource: Brewery.Supplier

          forms do
            exclude([:update, :rename])

            action :create do
              field :name, type: :combobox, autofocus: true
              field :code
              field :contact_email
              field :phone
              field :active
              field :notes
            end
          end
        end
      end
    end
  end

  describe "combobox validation" do
    test "a free-text combobox needs a string type" do
      assert_dsl_error ~r/combobox :active is not the foreign key of a `belongs_to`, so it is free text, and free text needs a `:string` or `:ci_string`\. The type is Ash\.Type\.Boolean/ do
        defmodule FreeTextNotString do
          use PyroManiac, resource: Brewery.Supplier

          forms do
            exclude([:update, :rename])

            action :create do
              field :name, autofocus: true
              field :code
              field :contact_email
              field :phone
              combobox :active
              field :notes
            end
          end
        end
      end
    end

    test "read_action must exist (with did-you-mean)" do
      assert_dsl_error ~r/read_action :suggest_cods does not exist on Brewery\.Supplier.*:suggest_codes/s do
        defmodule MissingReadAction do
          use PyroManiac, resource: Brewery.Supplier

          forms do
            exclude([:update, :rename])

            action :create do
              field :name, autofocus: true

              combobox :code do
                read_action :suggest_cods
              end

              field :contact_email
              field :phone
              field :active
              field :notes
            end
          end
        end
      end
    end

    test "read_action must be a read action" do
      assert_dsl_error ~r/read_action :destroy of Brewery\.Supplier is a :destroy action/ do
        defmodule NotReadAction do
          use PyroManiac, resource: Brewery.Supplier

          forms do
            exclude([:update, :rename])

            action :create do
              field :name, autofocus: true

              combobox :code do
                read_action :destroy
              end

              field :contact_email
              field :phone
              field :active
              field :notes
            end
          end
        end
      end
    end

    test "required arguments of read_action must be given" do
      assert_dsl_error ~r/Brewery\.Supplier\.by_prefix has required arguments that no `argument` gives: \[:prefix\]/ do
        defmodule MissingArgument do
          use PyroManiac, resource: Brewery.Supplier

          forms do
            exclude([:update, :rename])

            action :create do
              field :name, autofocus: true

              combobox :code do
                read_action :by_prefix
              end

              field :contact_email
              field :phone
              field :active
              field :notes
            end
          end
        end
      end
    end

    test "an argument must be an argument of read_action (with did-you-mean)" do
      assert_dsl_error ~r/:serch is not an argument of Brewery\.Supplier\.suggest_codes.*Did you mean:\s+\* :search/s do
        defmodule BadArgumentKey do
          use PyroManiac, resource: Brewery.Supplier

          forms do
            exclude([:update, :rename])

            action :create do
              field :name, autofocus: true

              combobox :code do
                read_action :suggest_codes
                argument :search, search()
                argument :serch, search()
              end

              field :contact_email
              field :phone
              field :active
              field :notes
            end
          end
        end
      end
    end

    test "an argument is given once" do
      assert_dsl_error ~r/combobox :code gives the argument :search more than once/ do
        defmodule DuplicateArgument do
          use PyroManiac, resource: Brewery.Supplier

          forms do
            exclude([:update, :rename])

            action :create do
              field :name, autofocus: true

              combobox :code do
                read_action :suggest_codes
                argument :search, search()
                argument :search, "x"
              end

              field :contact_email
              field :phone
              field :active
              field :notes
            end
          end
        end
      end
    end

    test "the typed text must filter the options" do
      assert_dsl_error ~r/the typed text does not filter the options of combobox :code/ do
        defmodule SearchNotUsed do
          use PyroManiac, resource: Brewery.Supplier

          forms do
            exclude([:update, :rename])

            action :create do
              field :name, autofocus: true

              combobox :code do
                search false
              end

              field :contact_email
              field :phone
              field :active
              field :notes
            end
          end
        end
      end
    end

    test "a search field must be a string" do
      assert_dsl_error ~r/combobox :code searches :active, which is a Ash\.Type\.Boolean/ do
        defmodule SearchNotString do
          use PyroManiac, resource: Brewery.Supplier

          forms do
            exclude([:update, :rename])

            action :create do
              field :name, autofocus: true

              combobox :code do
                search [:active]
              end

              field :contact_email
              field :phone
              field :active
              field :notes
            end
          end
        end
      end
    end

    test "sort must not be empty" do
      assert_dsl_error ~r/the `sort` of combobox :code is empty/ do
        defmodule EmptySort do
          use PyroManiac, resource: Brewery.Supplier

          forms do
            exclude([:update, :rename])

            action :create do
              field :name, autofocus: true

              combobox :code do
                sort []
              end

              field :contact_email
              field :phone
              field :active
              field :notes
            end
          end
        end
      end
    end

    test "a free-text sort must start with the value key" do
      assert_dsl_error ~r/free-text combobox :code gets the different values of :code, so its `sort` must start with it/ do
        defmodule FreeTextSort do
          use PyroManiac, resource: Brewery.Supplier

          forms do
            exclude([:update, :rename])

            action :create do
              field :name, autofocus: true

              combobox :code do
                sort name: :asc
              end

              field :contact_email
              field :phone
              field :active
              field :notes
            end
          end
        end
      end
    end

    test "limit must be from 1 to 100" do
      assert_dsl_error ~r/the `limit` of combobox :code is 500.*use a limit from 1 to 100/s do
        defmodule BigLimit do
          use PyroManiac, resource: Brewery.Supplier

          forms do
            exclude([:update, :rename])

            action :create do
              field :name, autofocus: true

              combobox :code do
                limit 500
              end

              field :contact_email
              field :phone
              field :active
              field :notes
            end
          end
        end
      end
    end

    test "^input(name) must name an input at the same level (with did-you-mean)" do
      assert_dsl_error ~r/combobox :code uses `\^input\(:nme\)`, but the form has no input :nme at the same level.*:name/s do
        defmodule BadInputRef do
          use PyroManiac, resource: Brewery.Supplier

          forms do
            exclude([:update, :rename])

            action :create do
              field :name, autofocus: true

              combobox :code do
                filter expr(is_nil(^input(:nme)) or name == ^input(:nme))
              end

              field :contact_email
              field :phone
              field :active
              field :notes
            end
          end
        end
      end
    end

    test "the filter must be a valid expression for the resource" do
      assert_dsl_error ~r/the `filter` of combobox :code is invalid/ do
        defmodule BadFilter do
          use PyroManiac, resource: Brewery.Supplier

          forms do
            exclude([:update, :rename])

            action :create do
              field :name, autofocus: true

              combobox :code do
                filter expr(no_such_field == true)
              end

              field :contact_email
              field :phone
              field :active
              field :notes
            end
          end
        end
      end
    end

    test "a free-text label key cannot differ from the value key" do
      assert_dsl_error ~r/free-text combobox :code shows its value as the label, but `label_key` is :name and the value key is :code/ do
        defmodule FreeTextLabelKey do
          use PyroManiac, resource: Brewery.Supplier

          forms do
            exclude([:update, :rename])

            action :create do
              field :name, autofocus: true

              combobox :code do
                label_key :name
              end

              field :contact_email
              field :phone
              field :active
              field :notes
            end
          end
        end
      end
    end

    test "a free-text combobox on an argument needs search and value_key" do
      assert_dsl_error ~r/combobox :reason searches :reason, which is not a field of Brewery\.Supplier.*An argument is not stored/s do
        defmodule FreeTextArgument do
          use PyroManiac, resource: Brewery.Supplier

          forms do
            exclude([:create, :update])

            action :rename do
              field :name, autofocus: true
              combobox :reason
            end
          end
        end
      end
    end

    test "a free-text combobox on an argument with search and value_key compiles" do
      defmodule FreeTextArgumentOk do
        use PyroManiac, resource: Brewery.Supplier

        forms do
          exclude([:create, :update])

          action :rename do
            field :name, autofocus: true

            combobox :reason do
              search [:code]
              value_key :code
            end
          end
        end
      end

      combobox =
        FreeTextArgumentOk
        |> PyroManiac.Info.form_for(:rename)
        |> PyroManiac.Info.form_fields()
        |> Enum.find(&(&1.name == :reason))

      assert combobox.label_key == :code
      assert combobox.value_key == :code
    end
  end

  describe "layout" do
    test "a row needs at least 2 children" do
      assert_dsl_error ~r/a `row` needs at least 2 children/ do
        defmodule ShortRow do
          use PyroManiac, resource: Brewery.Supplier

          forms do
            exclude([:update, :rename])

            action :create do
              field :name, autofocus: true

              row do
                field :code
              end

              field :contact_email
              field :phone
              field :active
              field :notes
            end
          end
        end
      end
    end

    test "a compound needs at least 2 parts" do
      assert_dsl_error ~r/compound "Code" has fewer than 2 parts/ do
        defmodule ShortCompound do
          use PyroManiac, resource: Brewery.Supplier

          forms do
            exclude([:update, :rename])

            action :create do
              field :name, autofocus: true

              compound "Code" do
                field :code
              end

              field :contact_email
              field :phone
              field :active
              field :notes
            end
          end
        end
      end
    end

    test "a part of a compound cannot be prose" do
      assert_dsl_error ~r/:notes has the size :prose\. The parts of a compound are tiny inputs/ do
        defmodule ProseCompound do
          use PyroManiac, resource: Brewery.Supplier

          forms do
            exclude([:update, :rename])

            action :create do
              field :name, autofocus: true

              compound "Contact" do
                field :phone
                field :notes, type: :textarea
              end

              field :code
              field :contact_email
              field :active
            end
          end
        end
      end
    end

    test "collapsed? needs collapsible?" do
      assert_dsl_error ~r/group "More" has `collapsed\? true` but not `collapsible\? true`/ do
        defmodule CollapsedOnly do
          use PyroManiac, resource: Brewery.Supplier

          forms do
            exclude([:update, :rename])

            action :create do
              field :name, autofocus: true

              group "More" do
                collapsed? true
                field :notes
              end

              field :code
              field :contact_email
              field :phone
              field :active
            end
          end
        end
      end
    end

    test "autofocus cannot be in a closed group" do
      assert_dsl_error ~r/group "More" starts closed, but it contains the input with `autofocus`/ do
        defmodule AutofocusClosed do
          use PyroManiac, resource: Brewery.Supplier

          forms do
            exclude([:update, :rename])

            action :create do
              group "More" do
                collapsible? true
                collapsed? true
                field :name, autofocus: true
              end

              field :code
              field :contact_email
              field :phone
              field :active
              field :notes
            end
          end
        end
      end
    end

    test "rows and compounds compose, with no maximum" do
      defmodule RowOfCompounds do
        use PyroManiac, resource: Brewery.Supplier

        forms do
          exclude([:update, :rename])

          action :create do
            field :name, autofocus: true

            row do
              compound "Identity" do
                field :code
                field :phone
              end

              field :contact_email
              field :active
              field :notes, size: :name
            end
          end
        end
      end

      [_, %PyroManiac.Form.Row{fields: [compound | _] = children}] =
        RowOfCompounds |> PyroManiac.Info.form_for(:create) |> Map.get(:fields)

      assert length(children) == 4
      assert %PyroManiac.Form.Compound{label: "Identity"} = compound
    end
  end

  describe "visible?" do
    test "parent(...) at the top level is not accepted" do
      assert_dsl_error ~r/it uses `parent\(...\)`, but there is no level above it/ do
        defmodule WhenParentTopLevel do
          use PyroManiac, resource: Brewery.Supplier

          forms do
            exclude([:update, :rename])

            action :create do
              field :name, autofocus: true
              field :code, visible?: expr(parent(active) == true)
              field :contact_email
              field :phone
              field :active
              field :notes
            end
          end
        end
      end
    end

    test "a parent field that does not exist is not accepted" do
      assert_dsl_error ~r/the `visible\?` expression is invalid/ do
        defmodule VisibleParentUnknown do
          use PyroManiac, resource: Brewery.Shipment

          forms do
            action :create do
              field :reference, autofocus: true

              group "Lines" do
                path [:lines]
                field :description, visible?: expr(parent(no_such_field) == 1)
              end
            end
          end
        end
      end
    end

    test "a parent field must be an attribute" do
      assert_dsl_error ~r/it refers to :line_count, which is not an attribute/ do
        defmodule VisibleParentAggregate do
          use PyroManiac, resource: Brewery.Shipment

          forms do
            action :create do
              field :reference, autofocus: true

              group "Lines" do
                path [:lines]
                field :description, visible?: expr(parent(line_count) > 0)
              end
            end
          end
        end
      end
    end

    test "a function is not accepted" do
      assert_dsl_error ~r/`visible\?` is an Ash expression, not a function/ do
        defmodule WhenFunction do
          use PyroManiac, resource: Brewery.Supplier

          forms do
            exclude([:update, :rename])

            action :create do
              field :name, autofocus: true
              field :code, visible?: fn _form -> true end
              field :contact_email
              field :phone
              field :active
              field :notes
            end
          end
        end
      end
    end

    test "a relationship is not accepted" do
      assert_dsl_error ~r/the `visible\?` expression is invalid: it refers to the relationship path \[:ingredients\]/ do
        defmodule WhenRelationship do
          use PyroManiac, resource: Brewery.Supplier

          forms do
            exclude([:update, :rename])

            action :create do
              field :name, autofocus: true
              field :code, visible?: expr(ingredients.name == "Hops")
              field :contact_email
              field :phone
              field :active
              field :notes
            end
          end
        end
      end
    end

    test "an aggregate is not accepted" do
      assert_dsl_error ~r/the `visible\?` expression is invalid: it refers to :ingredient_count, which is not an attribute/ do
        defmodule WhenAggregate do
          use PyroManiac, resource: Brewery.Supplier

          forms do
            exclude([:update, :rename])

            action :create do
              field :name, autofocus: true
              field :code, visible?: expr(ingredient_count > 0)
              field :contact_email
              field :phone
              field :active
              field :notes
            end
          end
        end
      end
    end

    test "an unknown argument is not accepted (with did-you-mean)" do
      assert_dsl_error ~r/uses `\^arg\(:reasn\)`, which is not an argument of :rename.*:reason/s do
        defmodule WhenUnknownArg do
          use PyroManiac, resource: Brewery.Supplier

          forms do
            exclude([:create, :update])

            action :rename do
              field :name, autofocus: true, visible?: expr(not is_nil(^arg(:reasn)))
              field :reason
            end
          end
        end
      end
    end
  end

  describe "private fields" do
    test "an author cannot set a private field" do
      assert_raise Spark.Error.DslError, fn ->
        defmodule SetPrivate do
          use PyroManiac, resource: Brewery.Supplier

          forms do
            exclude([:update, :rename])

            action :create do
              field :name, autofocus: true, "__allow_nil?__": true
              field :code
              field :contact_email
              field :phone
              field :active
              field :notes
            end
          end
        end
      end
    end

    test "class is not an option" do
      assert_raise Spark.Error.DslError, ~r/unknown options \[:class\]/, fn ->
        Code.eval_string("""
        defmodule PyroManiac.DslErrors.FormsTest.ClassOption do
          use PyroManiac, resource: Brewery.Supplier

          forms do
            exclude([:update, :rename])

            action :create do
              field :name, autofocus: true
              field :code, class: "is-size-code"
              field :contact_email
              field :phone
              field :active
              field :notes
            end
          end
        end
        """)
      end
    end
  end
end
