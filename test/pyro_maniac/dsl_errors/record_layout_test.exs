Code.put_compiler_option(:debug_info, true)

defmodule PyroManiac.DslErrors.RecordLayoutTest do
  @moduledoc """
  The errors of the record tree (`section`, `tabs`, `related`,
  `attachments`, the read-only fields), of the `:card` view, and of the
  links. The links are checked by a verifier, so their errors are warnings
  on stderr.
  """
  use ExUnit.Case, async: false

  import PyroManiac.Test.DslError

  defmodule RecipeCard do
    @moduledoc false
    use PyroManiac, resource: Brewery.Recipe

    view :read do
      type :card
      primary? true

      section :recipe do
        field :name
      end
    end

    page do
      route "/test"
      exclude [:create, :update, :activate, :retire, :destroy, :list]
    end
  end

  defmodule LineCard do
    @moduledoc false
    use PyroManiac, resource: Brewery.ShipmentLine

    page do
      route "/test"
      exclude [:destroy, :create]
    end

    view :read do
      type :card
      primary? true

      section :main do
        field :description
      end
    end
  end

  defp assert_dsl_error_fn(pattern, fun) do
    error = assert_raise Spark.Error.DslError, fun
    assert Exception.message(error) =~ pattern
  end

  defp assert_dsl_warning_match(pattern, fun) do
    output = ExUnit.CaptureIO.capture_io(:stderr, fun)
    assert output =~ pattern
  end

  describe "tabs" do
    test "a record has one tabs" do
      assert_dsl_error ~r/a record has one `tabs`/ do
        defmodule TwoTabs do
          use PyroManiac, resource: Brewery.Shipment

          view :read do
            type :card
            primary? true

            section :main do
              field :reference
            end

            action :create do
              state :guard
              field :reference, autofocus: true
              select :carrier

              tabs do
                tab :a do
                  section :lines do
                    path [:lines]
                    field :description
                  end
                end

                tab :b do
                  field :line_count
                end
              end

              tabs do
                tab :c do
                  section :c do
                  end
                end

                tab :d do
                  section :d do
                  end
                end
              end
            end
          end
        end
      end
    end

    test "tabs is the last node of the top level" do
      assert_dsl_error ~r/a node is after `tabs`/ do
        defmodule AfterTabs do
          use PyroManiac, resource: Brewery.Shipment

          view :read do
            type :card
            primary? true

            section :main do
              field :reference
            end

            action :create do
              state :guard
              field :reference, autofocus: true

              tabs do
                tab :a do
                  section :lines do
                    path [:lines]
                    field :description
                  end
                end

                tab :b do
                  field :line_count
                end
              end

              select :carrier
            end
          end
        end
      end
    end

    test "tabs needs two tabs" do
      assert_dsl_error ~r/`tabs` needs at least 2 tabs/ do
        defmodule OneTab do
          use PyroManiac, resource: Brewery.Shipment

          view :read do
            type :card
            primary? true

            section :main do
              field :reference
            end

            action :create do
              state :guard
              field :reference, autofocus: true
              select :carrier

              tabs do
                tab :a do
                  section :lines do
                    path [:lines]
                    field :description
                  end
                end
              end
            end
          end
        end
      end
    end

    test "the names of the tabs are unique" do
      assert_dsl_error ~r/tab :a is already defined/ do
        defmodule DuplicateTab do
          use PyroManiac, resource: Brewery.Shipment

          view :read do
            type :card
            primary? true

            section :main do
              field :reference
            end

            action :create do
              state :guard
              field :reference, autofocus: true
              select :carrier

              tabs do
                tab :a do
                  section :lines do
                    path [:lines]
                    field :description
                  end
                end

                tab :a do
                  label "Again"
                  field :line_count
                end
              end
            end
          end
        end
      end
    end

    test "the count of a tab is an aggregate or a calculation" do
      assert_dsl_error ~r/count :reference is not a public aggregate or calculation/ do
        defmodule TabCount do
          use PyroManiac, resource: Brewery.Shipment

          view :read do
            type :card
            primary? true

            section :main do
              field :reference
            end

            action :create do
              state :guard
              field :reference, autofocus: true
              select :carrier

              tabs do
                tab :a do
                  count :reference

                  section :lines do
                    path [:lines]
                    field :description
                  end
                end

                tab :b do
                  field :line_count
                end
              end
            end
          end
        end
      end
    end

    test "the input with autofocus is not on a later tab" do
      assert_dsl_error ~r/contains the input with `autofocus`, but the form opens on the first tab/ do
        defmodule AutofocusLaterTab do
          use PyroManiac, resource: Brewery.Shipment

          view :read do
            type :card
            primary? true

            section :main do
              field :reference
            end

            action :create do
              state :guard
              select :carrier

              tabs do
                tab :a do
                  section :lines do
                    path [:lines]
                    field :description
                  end
                end

                tab :b do
                  field :reference, autofocus: true
                end
              end
            end
          end
        end
      end
    end
  end

  describe "related and attachments" do
    test "related is a public relationship" do
      assert_dsl_error ~r/:nope is not a public relationship of Brewery.Shipment/ do
        defmodule UnknownRelated do
          use PyroManiac, resource: Brewery.Shipment

          view :read do
            type :card
            primary? true

            section :main do
              field :reference
            end

            action :create do
              state :guard
              field :reference, autofocus: true
              select :carrier

              section :lines do
                path [:lines]
                field :description
              end

              related(:nope)
            end
          end
        end
      end
    end

    test "a delegated related has no fields" do
      assert_dsl_error ~r/has `delegate_to` and fields or `limit`/ do
        defmodule DelegatedRelatedFields do
          use PyroManiac, resource: Brewery.Shipment

          view :read do
            type :card
            primary? true

            section :main do
              field :reference
            end

            action :create do
              state :guard
              field :reference, autofocus: true
              select :carrier

              section :lines do
                path [:lines]
                field :description
              end

              related :lines do
                delegate_to BreweryWeb.RecipeLive
                field :description
              end
            end
          end
        end
      end
    end

    test "related is not in a section with a path" do
      assert_dsl_error ~r/`related :shipment` is in a section with a `path`/ do
        defmodule NestedRelated do
          use PyroManiac, resource: Brewery.Shipment

          view :read do
            type :card
            primary? true

            section :main do
              field :reference
            end

            action :create do
              state :guard
              field :reference, autofocus: true
              select :carrier

              section :lines do
                path [:lines]
                field :description
                related(:shipment)
              end
            end
          end
        end
      end
    end

    test "attachments is an AshStorage attachment" do
      assert_dsl_error ~r/:files is not an AshStorage attachment of Brewery.Shipment/ do
        defmodule UnknownAttachments do
          use PyroManiac, resource: Brewery.Shipment

          view :read do
            type :card
            primary? true

            section :main do
              field :reference
            end

            action :create do
              state :guard
              field :reference, autofocus: true
              select :carrier

              section :lines do
                path [:lines]
                field :description
              end

              attachments(:files)
            end
          end
        end
      end
    end

    test "a bulk action has no related records" do
      assert_dsl_error ~r/bulk_action :destroy has `related :lines`/ do
        defmodule BulkRelated do
          use PyroManiac, resource: Brewery.Shipment

          view :read do
            type :card
            primary? true

            section :main do
              field :reference
            end

            bulk_action :destroy do
              state :guard
              confirm false

              section :lines do
                related(:lines)
              end
            end
          end

          page do
            route "/test"
            exclude [:create]
          end
        end
      end
    end
  end

  describe "read-only fields and links in forms" do
    test "a read-only field links only through a relationship" do
      assert_dsl_error ~r/field :line_count is not a relationship, so it has no record to link to/ do
        defmodule ReadOnlyLink do
          use PyroManiac, resource: Brewery.Shipment

          view :read do
            type :card
            primary? true

            section :main do
              field :reference
            end

            action :create do
              state :guard
              field :reference, autofocus: true
              select :carrier

              section :lines do
                path [:lines]
                field :description
              end

              field :line_count do
                link_to BreweryWeb.RecipeLive
              end
            end
          end
        end
      end
    end

    test "a free-text combobox has no record to link to" do
      assert_dsl_error ~r/free-text combobox :reference has no record to link to/ do
        defmodule FreeTextLink do
          use PyroManiac, resource: Brewery.Shipment

          view :read do
            type :card
            primary? true

            section :main do
              field :reference
            end

            action :create do
              state :guard

              combobox :reference do
                autofocus true
                link_to BreweryWeb.RecipeLive
              end

              select :carrier

              section :lines do
                path [:lines]
                field :description
              end
            end
          end
        end
      end
    end

    test "a name that is not a field is still an error" do
      assert_dsl_error ~r/field :nope is not an accepted attribute or argument/ do
        defmodule NotAField do
          use PyroManiac, resource: Brewery.Shipment

          view :read do
            type :card
            primary? true

            section :main do
              field :reference
            end

            action :create do
              state :guard
              field :reference, autofocus: true
              select :carrier
              field :nope

              section :lines do
                path [:lines]
                field :description
              end
            end
          end
        end
      end
    end
  end

  describe "the primary views" do
    test "a page has a primary single view" do
      assert_dsl_error ~r/a page has a primary single view: a link to the page opens it/ do
        defmodule NoPrimary do
          use PyroManiac, resource: Brewery.Shipment

          view :read do
            type :card
          end

          page do
            route "/test"
            exclude [:create]
          end
        end
      end
    end

    test "a primary list view needs a primary single view" do
      assert_dsl_error ~r/the primary list view :read needs a primary single view/ do
        defmodule ListWithoutSingle do
          use PyroManiac, resource: Brewery.Shipment

          view :read do
            type :grid
            primary? true

            section :shipment do
              field :reference
            end
          end

          page do
            route "/test"
            exclude [:create]
          end
        end
      end
    end

    test "a page has one primary single view" do
      assert_dsl_error ~r/a page has one primary single view \(`:card`\)/ do
        defmodule TwoPrimaryCards do
          use PyroManiac, resource: Brewery.Recipe

          view :read do
            type :card
            primary? true

            section :main do
              field :name
            end
          end

          view :list do
            type :card
            primary? true
          end

          page do
            route "/test"
            exclude [:create, :update, :activate, :retire]
          end
        end
      end
    end

    test "a page has one primary list view" do
      assert_dsl_error ~r/a page has one primary list view/ do
        defmodule TwoPrimaryLists do
          use PyroManiac, resource: Brewery.Recipe

          view :read do
            type :card
            primary? true

            section :main do
              field :name
            end
          end

          view :read do
            type :grid
            primary? true

            section :recipe do
              field :name
            end
          end

          view :list do
            type :grid
            primary? true

            section :recipe do
              field :name
            end
          end

          page do
            route "/test"
            exclude [:create, :update, :activate, :retire]
          end
        end
      end
    end

    test "a render view is not a primary view" do
      assert_dsl_error ~r/a :render view is not a primary view/ do
        defmodule PrimaryRender do
          use PyroManiac, resource: Brewery.Shipment

          view :read do
            type :render
            primary? true
            render PyroManiac.LiveView, SomeComponent
          end

          view :read do
            type :card

            primary? true

            section :main do
              field :reference
            end
          end

          page do
            route "/test"
            exclude [:create]
          end
        end
      end
    end

    test "each view is designed: a card has a form or sections" do
      assert_dsl_error ~r/the `:card` view has no record tree/ do
        defmodule EmptyCard do
          use PyroManiac, resource: Brewery.Shipment

          view :read do
            type :card
            primary? true
          end

          page do
            route "/test"
            exclude [:create]
          end
        end
      end
    end

    test "each view is designed: a grid has sections or card?" do
      assert_dsl_error ~r/the `:grid` view has no record tree/ do
        defmodule EmptyGrid do
          use PyroManiac, resource: Brewery.Shipment

          view :read do
            type :grid
            primary? true
          end

          view :read do
            type :card
            primary? true

            section :shipment do
              field :reference
            end
          end

          page do
            route "/test"
            exclude [:create]
          end
        end
      end
    end

    test "a page has many cards, and one is primary" do
      defmodule TwoCards do
        use PyroManiac, resource: Brewery.Recipe

        view :read do
          type :card
          primary? true

          section :main do
            field :name
          end
        end

        view :list do
          type :card

          section :recipe do
            field :style
          end
        end

        page do
          route "/test"
          exclude [:create, :update, :activate, :retire, :destroy]
        end
      end

      assert %{name: [:read]} = PyroManiac.Info.primary_single_view(TwoCards)

      assert PyroManiac.Info.primary_list_view(TwoCards) ==
               PyroManiac.Info.primary_single_view(TwoCards)

      assert length(PyroManiac.Info.views_of_type(TwoCards, :card)) == 2
    end
  end

  describe "the card view" do
    test "an action of a view is a write action" do
      assert_dsl_error ~r/:read is a read action. The read action of a view is its name/ do
        defmodule CreateCard do
          use PyroManiac, resource: Brewery.Shipment

          view :read do
            type :card
            primary? true
            action [:read], :guard

            field :reference, autofocus: true
            select :carrier

            section :lines do
              path [:lines]
              field :description
            end
          end
        end
      end
    end

    test "a card has no columns" do
      assert_dsl_error ~r/a `:card` view has no columns: it shows one record/ do
        defmodule CardColumns do
          use PyroManiac, resource: Brewery.Shipment

          view :read do
            type :card
            primary? true
            column :reference

            section :shipment do
              field :reference
            end
          end

          page do
            route "/test"
            exclude [:create]
          end
        end
      end
    end

    test "the card uses only the surface of the resource" do
      assert_dsl_error ~r/\[recipe: \[batches: \[:batch_number\]\]\] is used here, but it is not in `loads` of `expose :read` on Brewery.Batch/ do
        defmodule CardNotExposed do
          use PyroManiac, resource: Brewery.Batch

          view :read do
            type :card
            primary? true

            section :batch do
              field :batch_number

              field :batches, path: [:recipe]
            end
          end

          page do
            route "/test"
            exclude [:create, :update, :start_brewing, :advance_status, :complete, :move_card]
          end
        end
      end
    end

    test "a section path is a path of relationships" do
      assert_dsl_error ~r/:nope in the path \[:nope\] is not a relationship of Brewery.Shipment/ do
        defmodule BadSectionPath do
          use PyroManiac, resource: Brewery.Shipment

          view :read do
            type :grid
            primary? true

            section :lines do
              path [:nope]
              field :description
            end
          end

          view :read do
            type :card

            primary? true

            section :main do
              field :reference
            end
          end

          page do
            route "/test"
            exclude [:create]
          end
        end
      end
    end
  end

  describe "links and grids (transformers)" do
    test "a node that shows one record has one link_to" do
      assert_dsl_error ~r/:reference has more than one `link_to`/ do
        defmodule TwoLinks do
          use PyroManiac, resource: Brewery.Shipment

          view :read do
            type :grid
            primary? true

            section :shipment do
              field :reference do
                link_to BreweryWeb.RecipeLive
                link_to BreweryWeb.BatchLive
              end
            end
          end

          view :read do
            type :card

            primary? true

            section :main do
              field :reference
            end
          end

          page do
            route "/test"
            exclude [:create]
          end
        end
      end
    end

    test "related has one record link and one list link" do
      assert_dsl_error ~r/:lines has more than one `link_to`/ do
        defmodule TwoListLinks do
          use PyroManiac, resource: Brewery.Shipment

          view :read do
            type :grid
            primary? true

            section :shipment do
              related :lines do
                link_to BreweryWeb.RecipeLive
                link_to BreweryWeb.BatchLive
              end
            end
          end

          view :read do
            type :card

            primary? true

            section :main do
              field :reference
            end
          end

          page do
            route "/test"
            exclude [:create]
          end
        end
      end
    end

    test "a grid with card? needs the card of the page" do
      assert_dsl_error ~r/the grid has `card\? true`, but the page has no primary `:card` view/ do
        defmodule GridNoCard do
          use PyroManiac, resource: Brewery.Shipment

          view :read do
            type :grid
            primary? true
            card? true
          end

          page do
            route "/test"
            exclude [:create]
          end
        end
      end
    end

    test "a grid with card? has no sections" do
      assert_dsl_error ~r/the grid has `card\? true` and its own nodes/ do
        defmodule GridCardAndSections do
          use PyroManiac, resource: Brewery.Recipe

          view :read do
            type :card
            primary? true

            section :recipe do
              field :name
            end
          end

          view :list do
            type :grid
            primary? true
            card? true

            section :recipe do
              field :style
            end
          end

          page do
            route "/test"
            exclude [:create, :update, :activate, :retire]
          end
        end
      end
    end

    test "related in a view section is a public relationship" do
      assert_dsl_error ~r/:nope is not a public relationship of Brewery.Shipment/ do
        defmodule ViewRelatedUnknown do
          use PyroManiac, resource: Brewery.Shipment

          view :read do
            type :grid
            primary? true

            section :shipment do
              related :nope
            end
          end

          view :read do
            type :card

            primary? true

            section :main do
              field :reference
            end
          end

          page do
            route "/test"
            exclude [:create]
          end
        end
      end
    end

    test "the decoration of a select is a decoration or an expression" do
      assert_dsl_error ~r/`decoration` is one of .* or an Ash expression, not :blue/ do
        defmodule SelectToneAtom do
          use PyroManiac, resource: Brewery.Shipment

          view :read do
            type :card
            primary? true
            action [:create], :guard

            field :reference, autofocus: true
            select :carrier, decoration: :blue

            section :lines do
              path [:lines]
              field :description
            end
          end
        end
      end
    end

    test "the decoration of a form field is a decoration or an expression" do
      assert_dsl_error ~r/`decoration` is one of .* or an Ash expression, not :blue/ do
        defmodule FieldToneAtom do
          use PyroManiac, resource: Brewery.Shipment

          view :read do
            type :card
            primary? true

            section :main do
              field :reference
            end

            action :create do
              state :guard
              field :reference, autofocus: true, decoration: :blue
              select :carrier

              section :lines do
                path [:lines]
                field :description
              end
            end
          end
        end
      end
    end
  end

  describe "links (verifier)" do
    test "the view of a link exists" do
      assert_dsl_warning_match(
        ~r/PyroManiac.DslErrors.RecordLayoutTest.LineCard has no single view \(`:card`\) :nope/,
        fn ->
          defmodule LinkNoView do
            use PyroManiac, resource: Brewery.Shipment

            view :read do
              type :card
              primary? true

              section :shipment do
                field :reference

                related :lines do
                  link_to PyroManiac.DslErrors.RecordLayoutTest.LineCard do
                    single_view(:nope)
                  end
                end
              end
            end

            page do
              route "/test"
              exclude [:create, :destroy]
            end
          end
        end
      )
    end

    test "the target page is on the resource of the record" do
      assert_dsl_warning_match(
        ~r/PyroManiac.DslErrors.RecordLayoutTest.RecipeCard shows Brewery.Recipe, but the relationship goes to Brewery.ShipmentLine/,
        fn ->
          defmodule LinkWrongResource do
            use PyroManiac, resource: Brewery.Shipment

            view :read do
              type :card
              primary? true

              section :shipment do
                field :reference

                related :lines do
                  link_to PyroManiac.DslErrors.RecordLayoutTest.RecipeCard
                end
              end
            end

            page do
              route "/test"
              exclude [:create, :destroy]
            end
          end
        end
      )
    end

    test "the source of a link goes through a relationship" do
      assert_dsl_error_fn(
        ~r/field :reference is not a relationship, so it has no record to link to/,
        fn ->
          defmodule LinkNoRelationship do
            use PyroManiac, resource: Brewery.Shipment

            view :read do
              type :card
              primary? true

              section :shipment do
                field :reference do
                  link_to PyroManiac.DslErrors.RecordLayoutTest.RecipeCard
                end
              end
            end

            page do
              route "/test"
              exclude [:create]
            end
          end
        end
      )
    end

    test "the page of a delegated related is on the destination" do
      assert_dsl_warning_match(
        ~r/BreweryWeb.RecipeLive shows Brewery.Recipe, but the relationship goes to Brewery.ShipmentLine/,
        fn ->
          defmodule RelatedWrongPage do
            use PyroManiac, resource: Brewery.Shipment

            page do
              route "/test"
              exclude [:destroy]
            end

            view :read do
              type :card
              primary? true

              section :main do
                field :reference
              end

              action :create do
                state :guard
                field :reference, autofocus: true
                select :carrier

                section :lines do
                  path [:lines]
                  field :description
                end

                related :lines do
                  delegate_to BreweryWeb.RecipeLive
                end
              end
            end
          end
        end
      )
    end
  end
end
