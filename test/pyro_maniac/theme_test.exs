defmodule PyroManiac.ThemeTest do
  @moduledoc false
  use ExUnit.Case, async: true

  import ExUnit.CaptureIO

  alias PyroManiac.Theme.BaseClass
  alias PyroManiac.Theme.BEM
  alias Spark.Dsl.Extension

  doctest PyroManiac.Theme, import: true

  describe "theme" do
    test "prepends prefix" do
      prefix = Extension.get_opt(BEM, [:theme], :prefix)

      BEM
      |> Extension.get_entities([:theme])
      |> Enum.each(fn
        %BaseClass{} = base_class ->
          assert prefix <> base_class.value == base_class.prefixed

        _ ->
          :ok
      end)
    end

    test "validates base class implementation" do
      [missing | implemented] = BEM.base_class_names()

      output =
        capture_io(:stderr, fn ->
          defmodule CustomTheme.MissingBaseClass do
            use PyroManiac.Theme

            theme do
              for name <- implemented do
                base_class name, "#{name}"
              end
            end
          end
        end)

      assert output =~ "[PyroManiac.ThemeTest.CustomTheme.MissingBaseClass]"
      assert output =~ "theme -> base_class"
      assert output =~ "The following base classes are not defined:"
      assert output =~ inspect(missing)
    end
  end
end
