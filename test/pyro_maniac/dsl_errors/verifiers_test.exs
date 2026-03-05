Code.put_compiler_option(:debug_info, true)

defmodule PyroManiac.DslErrors.VerifiersTest do
  @moduledoc """
  Spark verifiers run in the `@after_verify` hook and have their errors
  downgraded to compile-time warnings on stderr (deps/spark/lib/spark/dsl.ex:539),
  so `assert_raise` does not catch them. Capture stderr instead via the
  `assert_dsl_warning/2` helper.
  """
  use ExUnit.Case, async: false

  import PyroManiac.Test.DslError

  describe "ValidateDefaultLabel" do
    test "default_label references unknown field (with did-you-mean)" do
      expected = """
      [PyroManiac.DslErrors.VerifiersTest.BadDefaultLabel]
      pyro_maniac -> default_label defined in <FILE:LINE>:
        default_label :nme does not exist as an attribute, calculation, or aggregate on this resource

        Did you mean:
          * :name
      │
      <LINE> │             default_label :nme
      │             ~~~~~~~~~~~~~~~~~~
      │
      └─ <FILE:LINE>: (file)\
      """

      assert_dsl_warning expected do
        defmodule BadDefaultLabel do
          use Ash.Resource,
            domain: nil,
            data_layer: :embedded,
            extensions: [PyroManiac.Resource]

          pyro_maniac do
            default_label :nme
          end

          attributes do
            attribute :name, :string, public?: true
          end

          actions do
            defaults [:read]
          end
        end
      end
    end
  end

  describe "ResourceHasExtension" do
    defmodule NoLabelResource do
      @moduledoc false
      use Ash.Resource,
        domain: nil,
        data_layer: :embedded

      attributes do
        attribute :name, :string, public?: true
      end

      actions do
        defaults [:read]
      end
    end

    test "page resource without PyroManiac.Resource extension" do
      expected = """
      [PyroManiac.DslErrors.VerifiersTest.PageOnNoLabel]
      resource :
        resource PyroManiac.DslErrors.VerifiersTest.NoLabelResource must use the PyroManiac.Resource extension with a default_label configured

        Fix: add `extensions: [PyroManiac.Resource]` to PyroManiac.DslErrors.VerifiersTest.NoLabelResource and configure `pyro_maniac do default_label :foo end`\
      """

      assert_dsl_warning expected do
        defmodule PageOnNoLabel do
          use PyroManiac, resource: PyroManiac.DslErrors.VerifiersTest.NoLabelResource

          forms do
            exclude([:create, :update])
          end
        end
      end
    end
  end
end
