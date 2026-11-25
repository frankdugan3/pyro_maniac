defmodule PyroManiac.PresenceTest do
  use ExUnit.Case, async: true

  alias Brewery.Recipe
  alias PyroManiac.SubscriptionManager

  doctest PyroManiac.SubscriptionManager

  describe "view presence" do
    test "is of the page, not of its resource" do
      assert SubscriptionManager.view_presence_topic(BreweryWeb.RecipeLive) ==
               "pyro_maniac:presence:page:BreweryWeb.RecipeLive"
    end
  end

  describe "edit presence" do
    test "is of the resource and the action, not of a page" do
      assert SubscriptionManager.edit_presence_topic(Recipe, :update) ==
               "pyro_maniac:presence:edit:Brewery.Recipe:update"

      refute SubscriptionManager.edit_presence_topic(Recipe, :update) ==
               SubscriptionManager.edit_presence_topic(Recipe, :retire)
    end

    test "a resource has a topic for each exposed action that changes a record" do
      topics = SubscriptionManager.edit_presence_topics(Recipe)

      for action <- [:update, :activate, :retire, :destroy] do
        assert SubscriptionManager.edit_presence_topic(Recipe, action) in topics
      end

      for action <- [:read, :list, :create] do
        refute SubscriptionManager.edit_presence_topic(Recipe, action) in topics
      end
    end
  end
end
