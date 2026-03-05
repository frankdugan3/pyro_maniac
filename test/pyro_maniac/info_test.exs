defmodule PyroManiac.InfoTest do
  @moduledoc false
  use ExUnit.Case, async: true

  doctest PyroManiac.Info, import: true

  defmodule StaffPage do
    @moduledoc false

    use PyroManiac, resource: Brewery.Staff

    views do
      view [:read, :list] do
        type :data_table
        default_sort "email"
        exclude([:id, :name_email])
        column(:name)
        column(:email)
        column(:role)
        column(:active)
      end
    end

    forms do
      exclude([:deactivate])

      action [:create, :update] do
        class "max-w-md justify-self-center"

        field_group "Identity" do
          class "md:grid-cols-2"

          field :name do
            description "Full name"
            autofocus(true)
          end

          field :email
        end

        field_group "Role & Status" do
          class "md:grid-cols-2"

          field :role do
            label("Role")
          end

          field :active do
            label("Active")
          end
        end
      end
    end
  end
end
