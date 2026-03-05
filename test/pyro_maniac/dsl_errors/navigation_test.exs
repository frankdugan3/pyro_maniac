Code.put_compiler_option(:debug_info, true)

defmodule PyroManiac.DslErrors.NavigationTest do
  @moduledoc false
  use ExUnit.Case, async: false

  import PyroManiac.Test.DslError

  test "item with no target" do
    expected = """
    [PyroManiac.DslErrors.NavigationTest.NoTarget]
    nav -> item -> orphan defined in <FILE:LINE>:
      item :orphan must have exactly one of `page`, `module`, or `href`

      Fix: set one of `page MyApp.SomePage`, `module MyApp.LiveView`, or `href "/url"`
    │
    <LINE> │           item :orphan do
    │           ~~~~~~~~~~~~~~~
    │
    └─ <FILE:LINE>: (file)\
    """

    assert_dsl_error expected do
      defmodule NoTarget do
        use PyroManiac.Navigation

        nav do
          item :orphan do
            path "/orphan"
          end
        end
      end
    end
  end

  test "item with multiple targets" do
    expected = """
    [PyroManiac.DslErrors.NavigationTest.MultiTarget]
    nav -> item -> both defined in <FILE:LINE>:
      item :both has multiple targets — use only one of `page`, `module`, or `href`

      Fix: remove all but one of `page`, `module`, or `href`
    │
    <LINE> │           item :both do
    │           ~~~~~~~~~~~~~
    │
    └─ <FILE:LINE>: (file)\
    """

    assert_dsl_error expected do
      defmodule MultiTarget do
        use PyroManiac.Navigation

        nav do
          item :both do
            path "/both"
            page SomeModule
            module AnotherModule
          end
        end
      end
    end
  end

  test "module item without path" do
    expected = """
    [PyroManiac.DslErrors.NavigationTest.NoPath]
    nav -> item -> no_path defined in <FILE:LINE>:
      item :no_path with `module` requires a `path`

      Fix: add `path "/some-path"` to the item, or use a `page` reference instead
    │
    <LINE> │           item :no_path do
    │           ~~~~~~~~~~~~~~~~
    │
    └─ <FILE:LINE>: (file)\
    """

    assert_dsl_error expected do
      defmodule NoPath do
        use PyroManiac.Navigation

        nav do
          item :no_path do
            module SomeModule
          end
        end
      end
    end
  end

  test "path not starting with /" do
    expected = """
    [PyroManiac.DslErrors.NavigationTest.BadPath]
    nav -> item -> bad -> path defined in <FILE:LINE>:
      item :bad path must start with `/`, got: "no-slash"

      Fix: prefix the path with `/`, e.g. `path "/no-slash"`
    │
    <LINE> │             path "no-slash"
    │             ~~~~~~~~~~~~~~~
    │
    └─ <FILE:LINE>: (file)\
    """

    assert_dsl_error expected do
      defmodule BadPath do
        use PyroManiac.Navigation

        nav do
          item :bad do
            path "no-slash"
            module SomeModule
          end
        end
      end
    end
  end

  test "duplicate paths" do
    expected = """
    [PyroManiac.DslErrors.NavigationTest.DupPath]
    nav -> item -> two -> path defined in <FILE:LINE>:
      duplicate path "/same"
    │
    <LINE> │             path "/same"
    │             ~~~~~~~~~~~~
    │
    └─ <FILE:LINE>: (file)\
    """

    assert_dsl_error expected do
      defmodule DupPath do
        use PyroManiac.Navigation

        nav do
          item :one do
            path "/same"
            module ModuleA
          end

          item :two do
            path "/same"
            module ModuleB
          end
        end
      end
    end
  end

  test "duplicate names at same level" do
    expected = """
    [PyroManiac.DslErrors.NavigationTest.DupName]
    nav -> item -> foo defined in <FILE:LINE>:
      duplicate name :foo at the same level
    │
    <LINE> │           item :foo do
    │           ~~~~~~~~~~~~
    │
    └─ <FILE:LINE>: (file)\
    """

    assert_dsl_error expected do
      defmodule DupName do
        use PyroManiac.Navigation

        nav do
          item :foo do
            path "/a"
            module ModuleA
          end

          item :foo do
            path "/b"
            module ModuleB
          end
        end
      end
    end
  end

  test "icon and image both set" do
    expected = """
    [PyroManiac.DslErrors.NavigationTest.IconAndImage]
    nav -> item -> both_visual defined in <FILE:LINE>:
      :both_visual cannot have both `icon` and `image` — choose one

      Fix: remove either `icon` or `image`
    │
    <LINE> │           item :both_visual do
    │           ~~~~~~~~~~~~~~~~~~~~
    │
    └─ <FILE:LINE>: (file)\
    """

    assert_dsl_error expected do
      defmodule IconAndImage do
        use PyroManiac.Navigation

        nav do
          item :both_visual do
            path "/x"
            module SomeModule
            icon :some_icon
            image "/logo.png"
          end
        end
      end
    end
  end
end
