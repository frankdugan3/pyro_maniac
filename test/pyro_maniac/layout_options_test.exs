defmodule PyroManiac.LayoutOptionsTest do
  @moduledoc false
  # The layout options: the width of a page, of a view, and of the modal or
  # the drawer of a card or an action, and the orientation of a timeline, a
  # board, a stepper, the tabs, a workflow, and the navigation.
  use ExUnit.Case, async: false

  import PyroManiac.Test.DslError

  alias PyroManiac.Info

  describe "the types" do
    test "the widths and the orientations" do
      assert PyroManiac.Dsl.Type.widths() == [:full, :record, :form, :prose]
      assert PyroManiac.Dsl.Type.width() == {:one_of, [:full, :record, :form, :prose]}
      assert PyroManiac.Dsl.Type.orientations() == [:horizontal, :vertical]
      assert PyroManiac.Dsl.Type.orientation() == {:one_of, [:horizontal, :vertical]}
    end
  end

  describe "width" do
    defmodule DefaultWidthPage do
      @moduledoc false
      use PyroManiac, resource: Brewery.Recipe

      page do
        route "/default-width"
        exclude [:create, :update, :activate, :retire, :destroy, :list]
      end

      view :read do
        type :list
        primary? true
        field :name
      end

      view :read do
        type :card
        primary? true
        width :record

        section :main do
          field :name
        end
      end
    end

    defmodule FormWidthPage do
      @moduledoc false
      use PyroManiac, resource: Brewery.Recipe

      page do
        route "/form-width"
        width :form
        exclude [:create, :activate, :retire, :destroy, :list]
      end

      view :read do
        type :list
        primary? true
        field :name
      end

      view :read do
        type :card
        primary? true
        presentation :drawer
        width :prose

        action :update, :guard do
          width :form
          field :name, autofocus: true
          select :style
          field :description
          field :target_abv
          field :target_og
          field :target_fg
          select :status
        end

        section :main do
          field :name
        end
      end
    end

    test "a page is full width by default, and a view has the width of its page" do
      assert Info.width(DefaultWidthPage) == :full
      table = Info.view_for(DefaultWidthPage, :read, :list)
      assert table.width == nil
      assert Info.view_width(DefaultWidthPage, table) == :full
    end

    test "a view sets its own width" do
      card = Info.view_for(DefaultWidthPage, :read, :card)
      assert Info.view_width(DefaultWidthPage, card) == :record
    end

    test "the width of a page" do
      assert Info.width(FormWidthPage) == :form
      list = Info.view_for(FormWidthPage, :read, :list)
      assert Info.view_width(FormWidthPage, list) == :form
    end

    test "the width of the modal or the drawer of a card: :record by default" do
      assert Info.view_width(FormWidthPage, Info.view_for(FormWidthPage, :read, :card)) == :prose

      defaults = Info.view_for(DefaultWidthPage, :read, :card)
      assert Info.view_width(DefaultWidthPage, %{defaults | width: nil}) == :record

      assert Info.view_width(DefaultWidthPage, %{defaults | presentation: :page, width: nil}) ==
               :full
    end

    test "the width of the dialog of an action: :record by default" do
      card = Info.view_for(FormWidthPage, :read, :card)
      action = Enum.find(card.actions, &(&1.name == [:update]))
      assert Info.action_width(action) == :form
      assert Info.action_width(%{action | width: nil}) == :record
    end

    test "a width is an intent" do
      assert_raise Spark.Error.DslError, ~r/width/, fn ->
        defmodule WideWidth do
          use PyroManiac, resource: Brewery.Recipe

          page do
            route "/test"
            width :huge
            exclude [:create, :update, :activate, :retire, :destroy, :list]
          end

          view :read do
            type :card
            primary? true

            section :main do
              field :name
            end
          end
        end
      end
    end
  end

  describe "orientation of a view" do
    defmodule BoardPage do
      @moduledoc false
      use PyroManiac, resource: Brewery.Batch

      view :kanban_read do
        type :kanban
        field :batch_number
      end

      view :read do
        type :timeline
        date_field :brew_date
        field :batch_number
      end

      view :read do
        type :card
        primary? true

        section :main do
          field :batch_number
        end
      end
    end

    defmodule RowsBoardPage do
      @moduledoc false
      use PyroManiac, resource: Brewery.Batch

      view :kanban_read do
        type :kanban
        orientation :vertical
        field :batch_number
      end

      view :read do
        type :card
        primary? true

        section :main do
          field :batch_number
        end
      end
    end

    test "the defaults of a board and a timeline, none for the other types" do
      assert Info.view_for(BoardPage, :kanban_read, :kanban).orientation == :horizontal
      assert Info.view_for(BoardPage, :read, :timeline).orientation == :vertical
      assert Info.view_for(BoardPage, :read, :card).orientation == nil
    end

    test "a board with its lanes as rows" do
      assert Info.view_for(RowsBoardPage, :kanban_read, :kanban).orientation == :vertical
    end
  end

  describe "step_orientation" do
    defmodule StepsPage do
      @moduledoc false
      use PyroManiac, resource: Brewery.Recipe

      view :read do
        type :card
        primary? true
        step_orientation :vertical

        section :main do
          field :name
        end

        action :create, :guard do
          step :info do
            field :name, autofocus: true
            select :style
          end

          step :targets do
            field :description
            field :target_abv
            field :target_og
            field :target_fg
            select :status
          end
        end

        action :update, :guard do
          step_orientation :horizontal

          step :info do
            field :name, autofocus: true
            select :style
          end

          step :targets do
            field :description
            field :target_abv
            field :target_og
            field :target_fg
            select :status
          end
        end
      end
    end

    test "the view sets it for its forms, an action sets its own" do
      card = Info.view_for(StepsPage, :read, :card)
      assert card.step_orientation == :vertical
      actions = Map.new(card.actions, &{hd(&1.name), &1.step_orientation})
      assert actions == %{create: nil, update: :horizontal}
    end

    test "the default" do
      assert Info.view_for(PyroManiac.LayoutOptionsTest.BoardPageForSteps, :read, :card).step_orientation ==
               :horizontal
    end

    test "a view without steps has no step orientation" do
      assert_dsl_error ~r/`step_orientation` is the axis of the stepper of the `step` entities of a form, but this form has no `step`/ do
        defmodule NoSteps do
          use PyroManiac, resource: Brewery.Recipe

          view :read do
            type :card
            primary? true
            step_orientation :vertical

            section :main do
              field :name
            end
          end
        end
      end
    end

    test "an action without steps has no step orientation" do
      assert_dsl_error ~r/`step_orientation` is the axis of the stepper/ do
        defmodule ActionNoSteps do
          use PyroManiac, resource: Brewery.Recipe

          view :read do
            type :card
            primary? true

            section :main do
              field :name
            end

            action :update, :guard do
              step_orientation :vertical
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

  describe "tabs and workflow" do
    defmodule TabsPage do
      @moduledoc false
      use PyroManiac, resource: Brewery.Recipe

      view :read do
        type :card
        primary? true

        tabs do
          orientation :vertical

          tab :details do
            field :name
          end

          tab :more do
            field :description
          end
        end
      end
    end

    defmodule DefaultTabsPage do
      @moduledoc false
      use PyroManiac, resource: Brewery.Recipe

      view :read do
        type :card
        primary? true

        tabs do
          tab :details do
            field :name
          end
        end
      end
    end

    defp tabs(page),
      do:
        Enum.find(Info.view_for(page, :read, :card).fields, &is_struct(&1, PyroManiac.Form.Tabs))

    test "the orientation of the tabs" do
      assert tabs(DefaultTabsPage).orientation == :horizontal
      assert tabs(TabsPage).orientation == :vertical
    end

    test "a badge has no orientation" do
      assert_dsl_error ~r/`orientation` is the axis of the states of `type :steps`, but this workflow is `type :badge`/ do
        defmodule BadgeOrientation do
          use PyroManiac, resource: Brewery.Recipe

          page do
            route "/test"
            exclude [:create, :update, :activate, :retire, :destroy, :list]
          end

          view :read do
            type :card
            primary? true
            field :name

            workflow do
              type :badge
              orientation :vertical
            end
          end
        end
      end
    end
  end

  describe "navigation" do
    defmodule TopNavigation do
      @moduledoc false
      use PyroManiac.Navigation

      nav do
        orientation :horizontal

        item :home do
          path "/"
          module BreweryWeb.HomeLive
        end
      end
    end

    test "a sidebar by default, or a top bar" do
      assert PyroManiac.Navigation.Info.orientation(BreweryWeb.Navigation) == :vertical
      assert PyroManiac.Navigation.Info.orientation(TopNavigation) == :horizontal
    end
  end

  # The view of the default stepper (no `step_orientation`).
  defmodule BoardPageForSteps do
    @moduledoc false
    use PyroManiac, resource: Brewery.Recipe

    view :read do
      type :card
      primary? true

      section :main do
        field :name
      end
    end
  end
end
