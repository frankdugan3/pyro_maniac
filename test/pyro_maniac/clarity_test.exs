defmodule PyroManiac.ClarityTest do
  @moduledoc false
  use ExUnit.Case, async: true

  alias Clarity.Vertex
  alias PyroManiac.Clarity.{KanBanDiagram, NavigationDiagram, PageDiagram}

  describe "registration" do
    test "all three providers are listed in the application env" do
      providers = Application.get_env(:pyro_maniac, :clarity_content_providers, [])
      assert NavigationDiagram in providers
      assert PageDiagram in providers
      assert KanBanDiagram in providers
    end
  end

  describe "NavigationDiagram" do
    test "applies to PyroManiac.Navigation modules" do
      assert NavigationDiagram.applies?(%Vertex.Module{module: BreweryWeb.Navigation}, nil)
    end

    test "rejects non-navigation modules" do
      refute NavigationDiagram.applies?(%Vertex.Module{module: BreweryWeb.RecipeLive}, nil)
      refute NavigationDiagram.applies?(%Vertex.Module{module: Enum}, nil)
    end

    test "renders a mermaid flowchart with the nav structure" do
      {:mermaid, fun} =
        NavigationDiagram.render_static(%Vertex.Module{module: BreweryWeb.Navigation}, nil)

      output = IO.iodata_to_binary(fun.(%{theme: :light}))

      assert output =~ "flowchart TD"
      assert output =~ "BreweryWeb.Navigation"
      assert output =~ "Brewery"
      assert output =~ "recipes"
      assert output =~ "BreweryWeb.RecipeLive"
      assert output =~ "/recipes"
      assert output =~ "https://docs.example.com"
    end
  end

  describe "PageDiagram" do
    test "applies to PyroManiac page modules" do
      assert PageDiagram.applies?(%Vertex.Module{module: BreweryWeb.RecipeLive}, nil)
    end

    test "rejects navigation modules and arbitrary modules" do
      refute PageDiagram.applies?(%Vertex.Module{module: BreweryWeb.Navigation}, nil)
      refute PageDiagram.applies?(%Vertex.Module{module: Enum}, nil)
    end

    test "renders a mermaid flowchart with the page's resource and views" do
      {:mermaid, fun} =
        PageDiagram.render_static(%Vertex.Module{module: BreweryWeb.RecipeLive}, nil)

      output = IO.iodata_to_binary(fun.(%{theme: :light}))

      assert output =~ "flowchart TD"
      assert output =~ "BreweryWeb.RecipeLive"
      assert output =~ "Brewery.Recipe"
      assert output =~ "Views"
      assert output =~ "data_table"
    end
  end

  describe "KanBanDiagram" do
    test "applies to Ash resources with PyroManiac.KanBan" do
      assert KanBanDiagram.applies?(%Vertex.Ash.Resource{resource: Brewery.Batch}, nil)
    end

    test "rejects resources without the extension" do
      refute KanBanDiagram.applies?(%Vertex.Ash.Resource{resource: Brewery.Recipe}, nil)
    end

    test "renders a mermaid flowchart with lanes from the enum" do
      {:mermaid, fun} =
        KanBanDiagram.render_static(%Vertex.Ash.Resource{resource: Brewery.Batch}, nil)

      output = IO.iodata_to_binary(fun.(%{theme: :light}))

      assert output =~ "flowchart TD"
      assert output =~ "Brewery.Batch"
      assert output =~ "lane: status"
      assert output =~ "priority: kanban_priority"
      assert output =~ "move_action: move_card"
      assert output =~ "read_action: kanban_read"
      assert output =~ "Lanes"
      assert output =~ "Planned"
      assert output =~ "Brewing"
    end
  end
end
