Code.put_compiler_option(:debug_info, true)

defmodule PyroManiac.DslErrors.PageTest do
  @moduledoc false
  use ExUnit.Case, async: false

  import PyroManiac.Test.DslError

  test "page route must start with /" do
    expected = """
    [PyroManiac.DslErrors.PageTest.BadRoute]
    page -> route defined in <FILE:LINE>:
      route must start with `/`, got: "recipes"

      Fix: prefix the route with `/`, e.g. `route "/recipes"`
    │
    <LINE> │           route "recipes"
    │           ~~~~~~~~~~~~~~~
    │
    └─ <FILE:LINE>: (file)\
    """

    assert_dsl_error expected do
      defmodule BadRoute do
        use PyroManiac, resource: Brewery.Recipe

        page do
          title "Recipes"
          route "recipes"
        end

        forms do
          exclude([:create, :update, :activate, :retire])
        end
      end
    end
  end
end
