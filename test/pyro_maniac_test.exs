defmodule PyroManiacTest do
  @moduledoc false
  use ExUnit.Case, async: true

  import ExUnit.CaptureIO

  alias PyroManiac.Test.Support.LiveViewBackend

  doctest PyroManiac, import: true

  defmodule Author do
    use Ash.Resource, domain: PyroManiacTest.Domain

    attributes do
      uuid_primary_key :id
      attribute :name, :ci_string, public?: true
      attribute :email, :ci_string
    end

    actions do
      defaults [:read, :destroy, create: :*, update: :*]
    end
  end

  defmodule Post do
    use Ash.Resource, domain: PyroManiacTest.Domain

    attributes do
      uuid_primary_key :id
      attribute :title, :ci_string, public?: true, description: "The title for this post."
      attribute :content, :ci_string, public?: true
    end

    relationships do
      belongs_to :author, PyroManiacTest.Author, public?: true, allow_nil?: false
    end

    actions do
      defaults [:read, create: :*]

      update :change_author do
        accept [:title, :content]
        argument :author, :map, allow_nil?: false
        change manage_relationship(:author, type: :direct_control)
      end
    end
  end

  defmodule Domain do
    use Ash.Domain

    resources do
      resource Post
      resource Author
    end
  end

  defmodule Blog.Page do
    use PyroManiac, resource: Post, backends: [LiveViewBackend]

    form do
      exclude [:change_author]

      action :create do
        field :title, autofocus: true
        field :content
        field :author_id, label: "Author"
      end
    end

    data_table do
      description :inherit

      action_type :read do
        default_sort "title"
        exclude [:id, :author_id, :author]
        column :title, description: :inherit
        column :content
      end
    end
  end

  test "works" do
    assert Post = Blog.Page.persisted(:resource, nil)

    assert ~w[Title Content Author] =
             Blog.Page
             |> PyroManiac.Info.form_for(:create)
             |> Map.get(:fields)
             |> Enum.map(& &1.label)
  end

  describe "form verifiers" do
    test "detect duplicate actions" do
      output =
        capture_io(:stderr, fn ->
          defmodule Blog.Form.DuplicateActions do
            use PyroManiac, resource: Post, backends: [LiveViewBackend]

            form do
              exclude [:change_author]

              action :create do
                field :title, autofocus: true
                field :content
                field :author_id
              end

              action :create do
                field :title, autofocus: true
                field :content
                field :author_id
              end
            end
          end
        end)

      assert output =~ "[PyroManiacTest.Blog.Form.DuplicateActions]"
      assert output =~ "form -> action"
      assert output =~ ":create is defined 2 times"
    end

    test "detect missing accept" do
      output =
        capture_io(:stderr, fn ->
          defmodule Blog.Form.MissingAccept do
            use PyroManiac, resource: Post, backends: [LiveViewBackend]

            form do
              exclude [:change_author]

              action :create do
                field :title, autofocus: true
                field :author_id
              end
            end
          end
        end)

      assert output =~ "[PyroManiacTest.Blog.Form.MissingAccept]"
      assert output =~ "form -> action -> create"
      assert output =~ "accepted attribute :content is not a form field"
    end

    test "detect missing argument" do
      output =
        capture_io(:stderr, fn ->
          defmodule Blog.Form.MissingArgument do
            use PyroManiac, resource: Post, backends: [LiveViewBackend]

            form do
              exclude [:create]

              action :change_author do
                field :title, autofocus: true
                field :content
              end
            end
          end
        end)

      assert output =~ "[PyroManiacTest.Blog.Form.MissingArgument]"
      assert output =~ "form -> action -> change_author"
      assert output =~ "argument :author is not a form field"
    end

    test "detect invalid field" do
      output =
        capture_io(:stderr, fn ->
          defmodule Blog.Form.InvalidField do
            use PyroManiac, resource: Post, backends: [LiveViewBackend]

            form do
              exclude [:change_author]

              action :create do
                field :title, autofocus: true
                field :content
                field :author_id
                field :not_real
              end
            end
          end
        end)

      assert output =~ "[PyroManiacTest.Blog.Form.InvalidField]"
      assert output =~ "form -> action -> create"
      assert output =~ "field :not_real is not an accepted attribute or argument for this action"
    end

    test "validate autofocus" do
      output =
        capture_io(:stderr, fn ->
          defmodule Blog.Form.ZeroAutofocus do
            use PyroManiac, resource: Post, backends: [LiveViewBackend]

            form do
              exclude [:change_author]

              action :create do
                field :title
                field :content
                field :author_id
              end
            end
          end
        end)

      assert output =~ "[PyroManiacTest.Blog.Form.ZeroAutofocus]"
      assert output =~ "form -> action -> create"
      assert output =~ "exactly one field must have autofocus"

      output =
        capture_io(:stderr, fn ->
          defmodule Blog.Form.TwoAutofocus do
            use PyroManiac, resource: Post, backends: [LiveViewBackend]

            form do
              exclude [:change_author]

              action :create do
                field :title, autofocus: true
                field :content, autofocus: true
                field :author_id
              end
            end
          end
        end)

      assert output =~ "[PyroManiacTest.Blog.Form.TwoAutofocus]"
      assert output =~ "form -> action -> create"
      assert output =~ "exactly one field must have autofocus"
    end

    test "detect duplicate field label" do
      output =
        capture_io(:stderr, fn ->
          defmodule Blog.Form.DuplicateFieldLabel do
            use PyroManiac, resource: Post, backends: [LiveViewBackend]

            form do
              exclude [:change_author]

              action :create do
                field :title, autofocus: true
                field :content, label: "Title"
                field :author_id
              end
            end
          end
        end)

      assert output =~ "[PyroManiacTest.Blog.Form.DuplicateFieldLabel]"
      assert output =~ "form -> action -> create"
      assert output =~ ~s(2 fields use the label "Title")
    end

    test "detect duplicate field" do
      output =
        capture_io(:stderr, fn ->
          defmodule Blog.Form.DuplicateField do
            use PyroManiac, resource: Post, backends: [LiveViewBackend]

            form do
              exclude [:change_author]

              action :create do
                field :title, autofocus: true
                field :content
                field :content, label: "Content 2"
                field :author_id
              end
            end
          end
        end)

      assert output =~ "[PyroManiacTest.Blog.Form.DuplicateField]"
      assert output =~ "form -> action -> create"
      assert output =~ "2 fields define :content"
    end
  end

  describe "data_table verifiers" do
    test "detect duplicate actions" do
      output =
        capture_io(:stderr, fn ->
          defmodule Blog.DataTable.DuplicateActions do
            use PyroManiac, resource: Post, backends: [LiveViewBackend]

            data_table do
              action :read do
                default_sort "title"
                exclude [:id, :author_id, :author]
                column :title
                column :content
              end

              action :read do
                default_sort "title"
                exclude [:id, :author_id, :author]
                column :title
                column :content
              end
            end
          end
        end)

      assert output =~ "[PyroManiacTest.Blog.DataTable.DuplicateActions]"
      assert output =~ "data_table -> action"
      assert output =~ ":read is defined 2 times"
    end

    test "detect duplicate column labels" do
      output =
        capture_io(:stderr, fn ->
          defmodule Blog.DataTable.DuplicateColumnLabels do
            use PyroManiac, resource: Post, backends: [LiveViewBackend]

            data_table do
              action :read do
                default_sort "title"
                exclude [:id, :author_id, :author]
                column :title
                column :content, label: "Title"
              end
            end
          end
        end)

      assert output =~ "[PyroManiacTest.Blog.DataTable.DuplicateColumnLabels]"
      assert output =~ "data_table -> action -> read"
      assert output =~ ~s(2 columns use the label "Title")
    end

    test "detect missing public columns" do
      output =
        capture_io(:stderr, fn ->
          defmodule Blog.DataTable.MissingPublicColumns do
            use PyroManiac, resource: Post, backends: [LiveViewBackend]

            data_table do
              action :read do
                default_sort "title"
                exclude [:id, :author_id, :author]
                column :title
              end
            end
          end
        end)

      assert output =~ "[PyroManiacTest.Blog.DataTable.MissingPublicColumns]"
      assert output =~ "data_table -> action -> read"
      assert output =~ "public attribute :content is not a defined or excluded column"
    end

    test "detect invalid default_sort" do
      output =
        capture_io(:stderr, fn ->
          defmodule Blog.DataTable.UndefinedColumnInDefaultSort do
            use PyroManiac, resource: Post, backends: [LiveViewBackend]

            data_table do
              action :read do
                default_sort "author_id"
                exclude [:id, :author_id, :author]
                column :title
                column :content
              end
            end
          end
        end)

      assert output =~ "[PyroManiacTest.Blog.DataTable.UndefinedColumnInDefaultSort]"
      assert output =~ "data_table -> action -> read -> default_sort"
      assert output =~ "key [:author_id] is an undefined or excluded column"

      output =
        capture_io(:stderr, fn ->
          defmodule Blog.DataTable.InvalidDefaultSort do
            use PyroManiac, resource: Post, backends: [LiveViewBackend]

            data_table do
              action :read do
                default_sort "---title"
                exclude [:id, :author_id, :author]
                column :title
                column :content
              end
            end
          end
        end)

      assert output =~ "[PyroManiacTest.Blog.DataTable.InvalidDefaultSort]"
      assert output =~ "data_table -> action -> read -> default_sort"
      assert output =~ ~s("---title" is an invalid Ash sort)
      assert output =~ "No such field -title for resource PyroManiacTest.Post"

      output =
        capture_io(:stderr, fn ->
          defmodule Blog.DataTable.NoSort do
            use PyroManiac, resource: Post, backends: [LiveViewBackend]

            data_table do
              action :read do
                default_sort ""
                exclude [:id, :author_id, :author]
                column :title
                column :content
              end
            end
          end
        end)

      assert output =~ "[PyroManiacTest.Blog.DataTable.NoSort]"
      assert output =~ "data_table -> action -> read -> default_sort"
      assert output =~ ~s("": must sort on at least one column)
    end

    test "detect invalid default_display" do
      output =
        capture_io(:stderr, fn ->
          defmodule Blog.DataTable.NoDefaultDisplay do
            use PyroManiac, resource: Post, backends: [LiveViewBackend]

            data_table do
              action :read do
                default_sort "title"
                default_display []
                exclude [:id, :author_id, :author]
                column :title
                column :content
              end
            end
          end
        end)

      assert output =~ "[PyroManiacTest.Blog.DataTable.NoDefaultDisplay]"
      assert output =~ "data_table -> action -> read -> default_display"
      assert output =~ "must display at least one column by default"

      output =
        capture_io(:stderr, fn ->
          defmodule Blog.DataTable.UndefinedColumnInDefaultDisplay do
            use PyroManiac, resource: Post, backends: [LiveViewBackend]

            data_table do
              action :read do
                default_sort "title"
                default_display [:not_real]
                exclude [:id, :author_id, :author]
                column :title
                column :content
              end
            end
          end
        end)

      assert output =~ "[PyroManiacTest.Blog.DataTable.UndefinedColumnInDefaultDisplay]"
      assert output =~ "data_table -> action -> read -> default_display"
      assert output =~ ":not_real is an undefined or excluded column"
    end

    test "detect invalid columns" do
      output =
        capture_io(:stderr, fn ->
          defmodule Blog.DataTable.ColumnSourceNotExist do
            use PyroManiac, resource: Post, backends: [LiveViewBackend]

            data_table do
              action :read do
                default_sort "title"
                exclude [:id, :author_id, :author]
                column :title
                column :content
                column :author_ssn, source: [:author, :ssn]
              end
            end
          end
        end)

      assert output =~ "[PyroManiacTest.Blog.DataTable.ColumnSourceNotExist]"
      assert output =~ "data_table -> action -> read -> columns"
      assert output =~ "column :author_ssn source [:author] -> :ssn does not exist on"

      output =
        capture_io(:stderr, fn ->
          defmodule Blog.DataTable.ColumnSourcePrivate do
            use PyroManiac, resource: Post, backends: [LiveViewBackend]

            data_table do
              action :read do
                default_sort "title"
                exclude [:id, :author_id, :author]
                column :title
                column :content
                column :author_email, source: [:author, :email]
              end
            end
          end
        end)

      assert output =~ "[PyroManiacTest.Blog.DataTable.ColumnSourcePrivate]"
      assert output =~ "data_table -> action -> read -> columns"
      assert output =~ "column :author_email source [:author] -> :email is not public on"
    end
  end
end
