Code.put_compiler_option(:debug_info, true)

defmodule PyroManiac.Dsl.ErrorTest do
  use ExUnit.Case, async: true

  alias PyroManiac.Dsl.Error

  describe "did_you_mean/3" do
    test "returns near matches sorted by similarity" do
      assert Error.did_you_mean(:targt_abv, [:target_abv, :targe_abv, :name, :id]) ==
               [:target_abv, :targe_abv]
    end

    test "filters out the target itself" do
      assert Error.did_you_mean(:foo, [:foo, :foox, :foooo]) == [:foox, :foooo]
    end

    test "respects threshold" do
      assert Error.did_you_mean(:abc, [:xyz, :abc_long_name], threshold: 0.95) == []
    end

    test "respects max" do
      assert Error.did_you_mean(:foo, [:foo1, :foo2, :foo3, :foo4], max: 2) |> length() == 2
    end

    test "works on strings" do
      assert Error.did_you_mean("name", ["nme", "nam", "other"]) == ["nam", "nme"]
    end

    test "ties broken by stringified name (deterministic)" do
      assert Error.did_you_mean(:foo, [:fox, :fop]) == [:fop, :fox]
    end

    test "empty candidates" do
      assert Error.did_you_mean(:anything, []) == []
    end
  end

  describe "build/1" do
    test "body = why only when no suggestions and no fix" do
      err =
        Error.build(
          module: __MODULE__,
          path: [:foo],
          why: "thing is wrong"
        )

      assert err.message == "thing is wrong"
      assert err.path == [:foo]
      assert err.location == nil
    end

    test "appends Did you mean: block" do
      err =
        Error.build(
          module: __MODULE__,
          path: [:foo],
          why: "unknown name",
          suggestions: [:target_abv, :actual_abv]
        )

      assert err.message == """
             unknown name

               Did you mean:
                 * :target_abv
                 * :actual_abv\
             """
    end

    test "appends Fix: block" do
      err =
        Error.build(
          module: __MODULE__,
          path: [:foo],
          why: "unknown name",
          fix: "rename it"
        )

      assert err.message == """
             unknown name

               Fix: rename it\
             """
    end

    test "appends both blocks in order" do
      err =
        Error.build(
          module: __MODULE__,
          path: [:foo],
          why: "unknown name",
          suggestions: [:foo],
          fix: "rename it"
        )

      assert err.message == """
             unknown name

               Did you mean:
                 * :foo

               Fix: rename it\
             """
    end

    test "passes path and location through" do
      err =
        Error.build(
          module: __MODULE__,
          path: [:views, :view, :read],
          location: :erl_anno.new(42),
          why: "x"
        )

      assert err.path == [:views, :view, :read]
      assert err.location == :erl_anno.new(42)
    end
  end

  describe "raise!/1" do
    test "raises a Spark.Error.DslError" do
      assert_raise Spark.Error.DslError, fn ->
        Error.raise!(module: __MODULE__, path: [:x], why: "boom")
      end
    end
  end

  describe "Spark anno capture in test files" do
    defmodule InlineFixture do
      use PyroManiac, resource: Brewery.Recipe

      forms do
        exclude([:create, :update, :activate, :retire])
      end

      views do
        view :read do
          type :data_table
          default_sort "name"

          exclude([
            :id,
            :recipe_ingredients,
            :batches,
            :photos,
            :photos_urls,
            :gravity_spread
          ])

          column :name
          column :style
          column :description
          column :status
          column :target_abv
          column :target_og
          column :target_fg
          column :ingredient_count
          column :batch_count
        end
      end
    end

    test "Code.get_compiler_option(:debug_info) is true" do
      assert Code.get_compiler_option(:debug_info) == true
    end

    test "view entity has a non-nil :erl_anno location with file and line" do
      [view] = PyroManiac.Info.views(InlineFixture)
      anno = Spark.Dsl.Entity.anno(view)
      assert anno, "expected non-nil anno; got #{inspect(view.__spark_metadata__)}"
      assert :erl_anno.file(anno) != :undefined
      location = :erl_anno.location(anno)
      assert location != :undefined and location != 0
    end
  end
end
