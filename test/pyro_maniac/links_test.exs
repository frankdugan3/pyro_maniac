defmodule PyroManiac.LinksTest do
  @moduledoc false
  # The links of the pages: the single links and the list links (with the
  # filter of the relationship), the views of a link, the primary views,
  # and the grids that show the card of their page.
  use ExUnit.Case, async: true

  alias PyroManiac.{Card, Info, Link, LinkTo}
  alias PyroManiac.Surface.Requirement
  alias PyroManiac.View.View

  defmodule Shop do
    @moduledoc false
    use Ash.Domain, validate_config_inclusion?: false

    resources do
      allow_unregistered? true
    end
  end

  defmodule Vendor do
    @moduledoc false
    use Ash.Resource,
      domain: PyroManiac.LinksTest.Shop,
      data_layer: Ash.DataLayer.Ets,
      extensions: [PyroManiac.Resource]

    pyro_maniac do
      default_label(:name)

      expose :read do
        loads [:*, :parts, :categories, :tags, :part_count]
        filter [:*, :parts, :categories]
        sort [:*]
      end

      expose(:update)
      expose(:assign_categories)
    end

    attributes do
      uuid_primary_key :id
      attribute :name, :string, public?: true, allow_nil?: false
      attribute :code, :string, public?: true
    end

    relationships do
      has_many :parts, PyroManiac.LinksTest.Part, public?: true

      many_to_many :categories, PyroManiac.LinksTest.Category,
        through: PyroManiac.LinksTest.VendorCategory,
        public?: true

      # No reverse relationship on Tag.
      many_to_many :tags, PyroManiac.LinksTest.Tag,
        through: PyroManiac.LinksTest.VendorTag,
        public?: true
    end

    aggregates do
      count :part_count, :parts, public?: true
    end

    actions do
      defaults [:read, update: [:name, :code]]

      update :assign_categories do
        require_atomic? false
        accept []
        argument :category_ids, {:array, :uuid}, allow_nil?: false
        change manage_relationship(:category_ids, :categories, type: :append_and_remove)
      end
    end
  end

  defmodule Part do
    @moduledoc false
    use Ash.Resource,
      domain: PyroManiac.LinksTest.Shop,
      data_layer: Ash.DataLayer.Ets,
      extensions: [PyroManiac.Resource]

    pyro_maniac do
      default_label(:name)

      expose :read do
        loads [:*, :vendor]
        filter [:*, :vendor]
        sort [:*, :vendor]
      end

      expose(:update)
    end

    attributes do
      uuid_primary_key :id
      attribute :name, :string, public?: true, allow_nil?: false
      attribute :weight, :integer, public?: true
    end

    relationships do
      belongs_to :vendor, PyroManiac.LinksTest.Vendor, public?: true
    end

    actions do
      defaults [:read, update: [:name, :weight]]
    end
  end

  defmodule Category do
    @moduledoc false
    use Ash.Resource,
      domain: PyroManiac.LinksTest.Shop,
      data_layer: Ash.DataLayer.Ets,
      extensions: [PyroManiac.Resource]

    pyro_maniac do
      default_label(:name)

      expose :read do
        loads [:*]
        filter [:*, vendors: [:id]]
        sort [:*]
      end

      expose :plain do
        loads [:*]
        filter []
        sort []
      end
    end

    attributes do
      uuid_primary_key :id
      attribute :name, :string, public?: true
    end

    relationships do
      many_to_many :vendors, PyroManiac.LinksTest.Vendor,
        through: PyroManiac.LinksTest.VendorCategory,
        public?: true
    end

    actions do
      defaults [:read]
      read :plain
    end
  end

  defmodule VendorCategory do
    @moduledoc false
    use Ash.Resource,
      domain: PyroManiac.LinksTest.Shop,
      data_layer: Ash.DataLayer.Ets

    relationships do
      belongs_to :vendor, PyroManiac.LinksTest.Vendor, primary_key?: true, allow_nil?: false
      belongs_to :category, PyroManiac.LinksTest.Category, primary_key?: true, allow_nil?: false
    end

    actions do
      defaults [:read]
    end
  end

  defmodule Tag do
    @moduledoc false
    use Ash.Resource,
      domain: PyroManiac.LinksTest.Shop,
      data_layer: Ash.DataLayer.Ets,
      extensions: [PyroManiac.Resource]

    pyro_maniac do
      default_label(:name)

      expose :read do
        loads [:*]
        filter [:*]
        sort [:*]
      end
    end

    attributes do
      uuid_primary_key :id
      attribute :name, :string, public?: true
    end

    actions do
      defaults [:read]
    end
  end

  defmodule VendorTag do
    @moduledoc false
    use Ash.Resource,
      domain: PyroManiac.LinksTest.Shop,
      data_layer: Ash.DataLayer.Ets

    relationships do
      belongs_to :vendor, PyroManiac.LinksTest.Vendor, primary_key?: true, allow_nil?: false
      belongs_to :tag, PyroManiac.LinksTest.Tag, primary_key?: true, allow_nil?: false
    end

    actions do
      defaults [:read]
    end
  end

  defmodule TagPage do
    @moduledoc false
    use PyroManiac, resource: PyroManiac.LinksTest.Tag

    # Only a card: it is also the primary list view.
    view :read do
      type :card
      primary? true

      section :main do
        field :name
      end
    end
  end

  defmodule VendorPage do
    @moduledoc false
    use PyroManiac, resource: PyroManiac.LinksTest.Vendor

    view :read do
      type :data_table
      primary? true
      exclude [:id, :parts, :categories, :tags, :part_count]
      column :name
      column :code

      action :update do
        state :guard
        field :name, autofocus: true

        field :part_count do
          decoration expr(if part_count > 0, do: :success)
        end

        field :code, decoration: :info
      end
    end

    view :read do
      type :card
      primary? true

      action :assign_categories do
        state :guard
        combobox :category_ids, autofocus: true
      end

      section :vendor do
        field :name
        field :code

        section :counts do
          field :part_count
        end
      end

      section :parts do
        related :parts do
          type :data_table
          presentation :modal
          limit 5
          field :name

          link_to PyroManiac.LinksTest.PartPage do
            list_view(:read)
          end
        end

        related :categories do
          type :badge
          link_to PyroManiac.LinksTest.CategoryPage
        end
      end
    end
  end

  defmodule PartPage do
    @moduledoc false
    use PyroManiac, resource: PyroManiac.LinksTest.Part

    view :read do
      type :data_table
      primary? true
      exclude [:id, :vendor_id]
      column :name
      column :weight

      column :vendor do
        link_to PyroManiac.LinksTest.VendorPage
      end

      # No link_to: no link.
      column :vendor_name do
        source [:vendor, :name]
      end
    end

    view :read do
      type :card
      primary? true
      action [:update], :guard

      row do
        section :part do
          field :name, autofocus: true

          field :vendor do
            link_to PyroManiac.LinksTest.VendorPage do
              single_view(:read)
            end
          end
        end

        section :more do
          field :vendor_id
        end
      end

      tabs do
        tab :one do
          field :id
        end

        tab :two do
          field :weight
        end
      end
    end

    view :read do
      type :grid
      card? true
    end
  end

  defmodule CategoryPage do
    @moduledoc false
    use PyroManiac, resource: PyroManiac.LinksTest.Category

    view :read do
      type :data_table
      primary? true
      exclude [:id]
      column :name
    end

    view :plain do
      type :data_table
      exclude [:id]

      column :name do
        filterable? false
        sortable? false
        keyset_sortable? false
      end
    end

    view :read do
      type :card

      primary? true

      section :main do
        field :name
      end
    end
  end

  defp origin(links, origin), do: Enum.filter(links, &(&1.origin == origin))

  describe "the primary views" do
    test "a page has a primary single view and a primary list view" do
      assert %View{type: :card} = Info.primary_single_view(PartPage)
      assert %View{type: :data_table} = Info.primary_list_view(PartPage)
    end

    test "a card that is the only primary view is also the primary list view" do
      card = Info.primary_single_view(TagPage)
      assert %View{type: :card} = card
      assert Info.primary_list_view(TagPage) == card
    end

    test "the views of a name" do
      assert [%View{type: :card}] = Info.named_views(PartPage, :single, :read)

      assert PartPage |> Info.named_views(:list, :read) |> Enum.map(& &1.type) |> Enum.sort() ==
               [:card, :data_table, :grid]
    end
  end

  describe "single links" do
    test "a node with link_to links to the page; a node without it has no link" do
      links = Card.links(PartPage)

      assert [%{kind: :single, link: %LinkTo{page: VendorPage}}] =
               origin(links, [:views, :view, :read, :column, :vendor])

      assert [] = origin(links, [:views, :view, :read, :column, :vendor_name])
    end

    test "a link loads the label of the record" do
      view = Info.view_for(PartPage, :read, :data_table)
      assert Info.link_paths(view, Part) == [[:vendor], [:vendor, :name]]
    end

    test "a single link opens the primary single view, or single_view" do
      assert {:ok, %{page: VendorPage, view: %View{type: :card}}} =
               Link.resolve(%LinkTo{page: VendorPage}, :single)

      assert {:ok, %{view: %View{type: :card}}} =
               Link.resolve(%LinkTo{page: VendorPage, single_view: :read}, :single)

      assert {:error, message} =
               Link.resolve(%LinkTo{page: VendorPage, single_view: :nope}, :single)

      assert message =~ "has no single view (`:card`) :nope"
    end

    test "a page that is not a PyroManiac page" do
      assert {:error, message} = Link.resolve(%LinkTo{page: String}, :single)
      assert message =~ "String is not a PyroManiac page"
    end
  end

  describe "list links" do
    test "a link on many records: a single link for each, and a list link" do
      links = VendorPage |> Card.links() |> Enum.filter(&(&1.record_path == [:parts]))

      assert [:list, :single] = links |> Enum.map(& &1.kind) |> Enum.sort()
      assert Enum.all?(links, &match?(%{link: %LinkTo{page: PartPage, list_view: :read}}, &1))
    end

    test "a list link opens the primary list view, or list_view" do
      assert {:ok, %{view: %View{type: :data_table}}} =
               Link.resolve(%LinkTo{page: CategoryPage}, :list)

      assert {:ok, %{view: %View{name: [:plain]}}} =
               Link.resolve(%LinkTo{page: CategoryPage, list_view: :plain}, :list)

      # Many list views of the name: the primary one.
      assert {:ok, %{view: %View{type: :data_table}}} =
               Link.resolve(%LinkTo{page: PartPage, list_view: :read}, :list)

      # A card alone is the primary list view.
      assert {:ok, %{view: %View{type: :card}}} = Link.resolve(%LinkTo{page: TagPage}, :list)
    end

    test "the filter of a has_many and of a many_to_many" do
      assert Link.list_filter_path(Vendor, [:parts]) == {[:vendor_id], :id}
      assert Link.list_filter(Vendor, [:parts], %{id: "v1"}) == %{"vendor_id" => %{"eq" => "v1"}}

      assert Link.list_filter_path(Vendor, [:categories]) == {[:vendors, :id], :id}

      assert Link.list_filter(Vendor, [:categories], %{id: "v1"}) ==
               %{"vendors" => %{"id" => %{"eq" => "v1"}}}
    end
  end

  describe "the checks of the links (verifier)" do
    test "a many_to_many without the reverse relationship has no list filter" do
      assert Link.list_filter_path(Vendor, [:tags]) == nil

      output =
        ExUnit.CaptureIO.capture_io(:stderr, fn ->
          defmodule TagsPage do
            @moduledoc false
            use PyroManiac, resource: PyroManiac.LinksTest.Vendor

            view :read do
              type :card
              primary? true

              section :tags do
                related :tags do
                  type :badge
                  link_to PyroManiac.LinksTest.TagPage
                end
              end
            end

            page do
              route "/test"
              exclude [:update, :assign_categories]
            end
          end
        end)

      assert output =~ "a `many_to_many` needs the reverse `many_to_many`"
    end

    test "the read action of the list exposes the filter" do
      output =
        ExUnit.CaptureIO.capture_io(:stderr, fn ->
          defmodule PlainCategoriesPage do
            @moduledoc false
            use PyroManiac, resource: PyroManiac.LinksTest.Vendor

            view :read do
              type :card
              primary? true

              section :categories do
                related :categories do
                  type :badge

                  link_to PyroManiac.LinksTest.CategoryPage do
                    list_view(:plain)
                  end
                end
              end
            end

            page do
              route "/test"
              exclude [:update, :assign_categories]
            end
          end
        end)

      assert output =~ "[vendors: [:id]]"
      assert output =~ "is not in `filter` of `expose :plain`"
    end

    test "list_view is for a relationship to many records" do
      output =
        ExUnit.CaptureIO.capture_io(:stderr, fn ->
          defmodule ListViewOnOnePage do
            @moduledoc false
            use PyroManiac, resource: PyroManiac.LinksTest.Part

            view :read do
              type :data_table
              primary? true
              exclude [:id, :vendor_id]
              column :name
              column :weight

              column :vendor do
                link_to PyroManiac.LinksTest.VendorPage do
                  list_view(:read)
                end
              end
            end

            view :read do
              type :card

              primary? true

              section :main do
                field :name
              end
            end

            page do
              route "/test"
              exclude [:update]
            end
          end
        end)

      assert output =~ "`list_view :read` is for a relationship to many records"
    end

    test "the page of a link is on the destination" do
      output =
        ExUnit.CaptureIO.capture_io(:stderr, fn ->
          defmodule WrongPagePage do
            @moduledoc false
            use PyroManiac, resource: PyroManiac.LinksTest.Part

            view :read do
              type :data_table
              primary? true
              exclude [:id, :vendor_id]
              column :name
              column :weight

              column :vendor do
                link_to PyroManiac.LinksTest.TagPage
              end
            end

            view :read do
              type :card

              primary? true

              section :main do
                field :name
              end
            end

            page do
              route "/test"
              exclude [:update]
            end
          end
        end)

      assert output =~ "shows PyroManiac.LinksTest.Tag, but the relationship goes to"
    end
  end

  describe "the card param" do
    test "the primary card, and another card of the page" do
      card = Info.primary_single_view(PartPage)

      assert Card.param(PartPage, card, "p1") == "p1"
      assert Card.parse_param(PartPage, "p1") == {:ok, card, "p1"}
      assert Card.parse_param(PartPage, "read:p1") == {:ok, card, "p1"}
      assert Card.parse_param(PartPage, "nope:p1") == :error
      assert Card.parse_param(PartPage, "read:") == :error
      assert Card.parse_param(PartPage, "") == :error
    end
  end

  describe "the same nodes in cards, grids, and forms" do
    test "a grid shows the card of its page" do
      grid = Info.view_for(PartPage, :read, :grid)
      card = Info.primary_single_view(PartPage)

      assert grid.card? and grid.fields == []
      assert Card.tree(grid) == Card.grid_tree(Card.tree(card))
      # The nodes before `tabs`: the row of sections.
      assert [%PyroManiac.Form.Row{}] = Card.tree(grid)
      assert [:name] in Card.paths(grid, Part)
      refute [:weight] in Card.paths(grid, Part)
    end

    test "a card section has nested sections and related" do
      card = Info.primary_single_view(VendorPage)
      [vendor, parts] = Card.tree(card)

      assert %PyroManiac.Form.Section{name: :vendor, label: "Vendor"} = vendor
      # A nested section keeps its place among the nodes.
      assert [_name, _code, %PyroManiac.Form.Section{name: :counts, label: "Counts"}] =
               vendor.fields

      assert Enum.map(PyroManiac.Form.Tree.values(vendor), & &1.name) ==
               [:name, :code, :part_count]

      assert [
               %PyroManiac.Form.Related{
                 name: :parts,
                 __destination__: Part,
                 type: :data_table,
                 presentation: :modal
               },
               %PyroManiac.Form.Related{name: :categories, presentation: :inline}
             ] = parts.fields

      paths = Card.paths(card, Vendor)
      assert [:parts, :name] in paths
      assert [:categories] in paths
      assert [:part_count] in paths
    end

    test "the loads and the requirement of a card with sections" do
      card = Info.primary_single_view(VendorPage)
      loads = Info.build_loads_from_view(card, Vendor)

      assert :part_count in loads
      assert {:parts, :name} in loads

      assert Enum.any?(
               Requirement.requirements(Vendor, [card], [], []),
               &([:parts, :name] in &1.loads)
             )
    end

    test "a form field has a decoration in view mode" do
      fields = VendorPage |> Info.action_for(:update) |> Map.fetch!(:fields)
      count = Enum.find(fields, &(&1.name == :part_count))
      code = Enum.find(fields, &(&1.name == :code))

      assert count.__decoration_refs__ == [:part_count]
      assert code.decoration == :info

      assert %{decoration: :info} =
               Enum.find(
                 Info.form_layout(Info.action_for(VendorPage, :update)).children,
                 &(&1.name == :code)
               )
    end
  end

  describe "attach and detach" do
    test "a combobox of an argument that the action passes to manage_relationship" do
      [combobox] = Info.action_for(VendorPage, :assign_categories).fields

      assert %PyroManiac.Form.Combobox{
               __mode__: :select,
               __relationship__: :categories,
               __resource__: Category,
               "__multiple?__": true
             } = combobox
    end
  end
end
