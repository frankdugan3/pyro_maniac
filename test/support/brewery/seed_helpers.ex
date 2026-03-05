defmodule Brewery.SeedHelpers do
  @moduledoc """
  Creates substantive brewery seed data for integration tests.
  """

  @scope %Brewery.Scope{}

  def seed_brewery! do
    truncate_all!()
    staff = seed_staff!()
    {suppliers, ingredients} = seed_suppliers_and_ingredients!()
    recipes = seed_recipes!(ingredients)
    batches = seed_batches!(recipes, staff)
    seed_quality_tests!(batches, staff)

    %{
      batches: batches,
      ingredients: ingredients,
      recipes: recipes,
      staff: staff,
      suppliers: suppliers
    }
  end

  defp truncate_all! do
    Ecto.Adapters.SQL.query!(Brewery.Repo, """
    TRUNCATE
      brewery_quality_tests,
      brewery_batches,
      brewery_recipe_ingredients,
      brewery_recipes,
      brewery_ingredients,
      brewery_suppliers,
      brewery_staff
    CASCADE
    """)
  end

  defp seed_staff! do
    names = [
      {"Alice", "Chen"},
      {"Bob", "Martinez"},
      {"Carol", "White"},
      {"Dave", "Kim"},
      {"Eve", "Johnson"},
      {"Frank", "Lee"},
      {"Grace", "Park"},
      {"Henry", "Zhang"},
      {"Iris", "Patel"},
      {"Jack", "Thompson"},
      {"Kate", "Wilson"},
      {"Liam", "Brown"},
      {"Maya", "Garcia"},
      {"Noah", "Davis"},
      {"Olivia", "Miller"},
      {"Pete", "Anderson"},
      {"Quinn", "Taylor"},
      {"Rosa", "Thomas"},
      {"Sam", "Jackson"},
      {"Tina", "Harris"},
      {"Uma", "Clark"},
      {"Vic", "Lewis"},
      {"Wendy", "Robinson"},
      {"Xander", "Walker"},
      {"Yuki", "Hall"},
      {"Zara", "Allen"},
      {"Aaron", "Young"},
      {"Beth", "King"},
      {"Chris", "Wright"},
      {"Diana", "Scott"}
    ]

    roles = [
      :head_brewer,
      :head_brewer,
      :brewer,
      :brewer,
      :admin,
      :brewer,
      :quality,
      :admin,
      :brewer,
      :head_brewer,
      :brewer,
      :brewer,
      :quality,
      :brewer,
      :brewer,
      :quality,
      :brewer,
      :brewer,
      :brewer,
      :quality,
      :brewer,
      :head_brewer,
      :brewer,
      :brewer,
      :quality,
      :brewer,
      :admin,
      :brewer,
      :brewer,
      :quality
    ]

    staff =
      names
      |> Enum.zip(roles)
      |> Enum.map(fn {{first, last}, role} ->
        Brewery.Staff
        |> Ash.Changeset.for_create(:create, %{
          email: "#{String.downcase(first)}.#{String.downcase(last)}@brewery.test",
          name: "#{first} #{last}",
          role: role
        })
        |> Ash.create!(scope: @scope)
      end)

    Enum.at(staff, 4)
    |> Ash.Changeset.for_update(:deactivate, %{})
    |> Ash.update!(scope: @scope)

    staff
  end

  defp seed_suppliers_and_ingredients! do
    suppliers_with_ingredients = [
      {"Malt Masters", "MM-001", "malt@masters.test",
       [
         {"Pale Malt", :grain, "LOT-PM-001"},
         {"Munich Malt", :grain, "LOT-MM-001"},
         {"Crystal 60", :grain, "LOT-C60-001"},
         {"Roasted Barley", :grain, "LOT-RB-001"},
         {"Chocolate Malt", :grain, "LOT-CM-001"},
         {"Wheat Malt", :grain, "LOT-WM-001"},
         {"Vienna Malt", :grain, "LOT-VM-001"},
         {"Pilsner Malt", :grain, "LOT-PIL-001"},
         {"Oat Flakes", :grain, "LOT-OAT-001"},
         {"Rye Malt", :grain, "LOT-RYE-001"}
       ]},
      {"Hop Haven", "HH-001", "hops@haven.test",
       [
         {"Cascade", :hop, "LOT-CAS-001"},
         {"Centennial", :hop, "LOT-CEN-001"},
         {"Citra", :hop, "LOT-CIT-001"},
         {"Simcoe", :hop, "LOT-SIM-001"},
         {"Fuggle", :hop, "LOT-FUG-001"},
         {"Saaz", :hop, "LOT-SAZ-001"},
         {"Mosaic", :hop, "LOT-MOS-001"},
         {"Amarillo", :hop, "LOT-AMA-001"},
         {"Galaxy", :hop, "LOT-GAL-001"},
         {"Nelson Sauvin", :hop, "LOT-NEL-001"}
       ]},
      {"Yeast Lab", "YL-001", "yeast@lab.test",
       [
         {"US-05 American Ale", :yeast, "LOT-US05-001"},
         {"S-04 English Ale", :yeast, "LOT-S04-001"},
         {"W-34/70 Lager", :yeast, "LOT-W34-001"},
         {"Belgian Wit", :yeast, "LOT-BW-001"},
         {"Saison Yeast", :yeast, "LOT-SAI-001"},
         {"Kveik", :yeast, "LOT-KVK-001"}
       ]},
      {"Water Works", "WW-001", "water@works.test",
       [
         {"Calcium Chloride", :water_treatment, "LOT-CC-001"},
         {"Gypsum", :water_treatment, "LOT-GYP-001"},
         {"Lactic Acid", :water_treatment, "LOT-LA-001"}
       ]},
      {"Adjunct Depot", "AD-001", "adjunct@depot.test",
       [
         {"Orange Peel", :adjunct, "LOT-OP-001"},
         {"Coriander", :adjunct, "LOT-COR-001"},
         {"Lactose", :adjunct, "LOT-LAC-001"},
         {"Vanilla Beans", :adjunct, "LOT-VAN-001"},
         {"Coffee Beans", :adjunct, "LOT-COF-001"},
         {"Cocoa Nibs", :adjunct, "LOT-COC-001"},
         {"Honey", :adjunct, "LOT-HON-001"}
       ]},
      {"Barrel House", "BH-001", "barrels@house.test",
       [
         {"Bourbon Barrel Chips", :adjunct, "LOT-BBC-001"},
         {"Oak Spirals", :adjunct, "LOT-OAK-001"},
         {"Rum Barrel Chips", :adjunct, "LOT-RBC-001"}
       ]}
    ]

    {suppliers, ingredients} =
      Enum.reduce(suppliers_with_ingredients, {[], []}, fn {name, code, email, ingredient_list},
                                                           {sup_acc, ing_acc} ->
        supplier =
          Brewery.Supplier
          |> Ash.Changeset.for_create(:create, %{
            active: true,
            code: code,
            contact_email: email,
            name: name
          })
          |> Ash.create!(scope: @scope)

        new_ingredients =
          Enum.map(ingredient_list, fn {ing_name, type, lot} ->
            Brewery.Ingredient
            |> Ash.Changeset.for_create(:create, %{
              lot_number: lot,
              name: ing_name,
              supplier_id: supplier.id,
              type: type
            })
            |> Ash.create!(scope: @scope)
          end)

        {[supplier | sup_acc], new_ingredients ++ ing_acc}
      end)

    {Enum.reverse(suppliers), Enum.reverse(ingredients)}
  end

  defp seed_recipes!(ingredients) do
    by_name = Map.new(ingredients, &{&1.name, &1})

    recipe_templates()
    |> Enum.map(fn {name, style, status, desc, abv, og, fg, ingredient_names} ->
      recipe =
        Brewery.Recipe
        |> Ash.Changeset.for_create(:create, %{
          description: desc,
          name: name,
          status: status,
          style: style,
          target_abv: Decimal.new(abv),
          target_fg: Decimal.new(fg),
          target_og: Decimal.new(og)
        })
        |> Ash.create!(scope: @scope)

      Enum.each(ingredient_names, fn ing_name ->
        if ingredient = Map.get(by_name, ing_name) do
          qty = Decimal.from_float(:rand.uniform(100) / 10.0)

          Brewery.RecipeIngredient
          |> Ash.Changeset.for_create(:create, %{
            ingredient_id: ingredient.id,
            quantity: qty,
            recipe_id: recipe.id
          })
          |> Ash.create!(scope: @scope)
        end
      end)

      recipe
    end)
  end

  defp recipe_templates do
    [
      {"Cascade IPA", :ipa, :active, "Bright, citrusy West Coast IPA with bold hop character.",
       "6.5", "1.062", "1.010", ["Pale Malt", "Crystal 60", "Cascade", "Citra"]},
      {"Midnight Stout", :stout, :active,
       "Rich, full-bodied stout with chocolate and coffee notes.", "5.8", "1.058", "1.014",
       ["Pale Malt", "Roasted Barley", "Chocolate Malt", "Fuggle"]},
      {"Golden Lager", :lager, :active, "Clean, crisp lager with subtle malt sweetness.", "4.8",
       "1.048", "1.008", ["Pilsner Malt", "Munich Malt", "Saaz"]},
      {"Hefeweizen", :wheat, :active,
       "Traditional Bavarian wheat beer with banana and clove esters.", "5.2", "1.052", "1.012",
       ["Wheat Malt", "Pale Malt", "Saaz"]},
      {"Tart Cherry Sour", :sour, :draft,
       "Kettle sour with tart cherry puree added in secondary.", "4.5", "1.045", "1.006",
       ["Pale Malt", "Wheat Malt"]},
      {"Porter Reserve", :porter, :active,
       "Smooth, malty porter with hints of caramel and dark fruit.", "5.5", "1.055", "1.013",
       ["Pale Malt", "Crystal 60", "Chocolate Malt", "Fuggle"]},
      {"Summer Pale Ale", :pale_ale, :retired,
       "Light, sessionable pale ale with tropical fruit hop aroma.", "4.2", "1.042", "1.010",
       ["Pale Malt", "Simcoe", "Citra"]},
      {"Double IPA", :ipa, :draft, "Aggressive hop-forward DIPA with resinous pine and citrus.",
       "8.5", "1.080", "1.012", ["Pale Malt", "Munich Malt", "Centennial", "Simcoe", "Citra"]},
      {"Belgian Witbier", :wheat, :active, "Spiced Belgian wheat with orange peel and coriander.",
       "4.8", "1.048", "1.010", ["Wheat Malt", "Pale Malt", "Saaz", "Orange Peel", "Coriander"]},
      {"Milk Stout", :stout, :active, "Sweet stout with lactose for a creamy mouthfeel.", "5.0",
       "1.054", "1.016", ["Pale Malt", "Chocolate Malt", "Roasted Barley", "Lactose", "Fuggle"]},
      {"Session IPA", :ipa, :active, "Low-ABV IPA that doesn't compromise on hop flavor.", "4.0",
       "1.040", "1.008", ["Pale Malt", "Citra", "Simcoe"]},
      {"Bourbon Barrel Porter", :porter, :draft,
       "Aged on bourbon barrel chips for vanilla and oak.", "7.2", "1.072", "1.018",
       ["Pale Malt", "Crystal 60", "Chocolate Malt", "Bourbon Barrel Chips", "Fuggle"]},
      {"New England IPA", :ipa, :active, "Hazy, juicy IPA with tropical hop character.", "6.8",
       "1.065", "1.012", ["Pale Malt", "Wheat Malt", "Oat Flakes", "Citra", "Mosaic", "Galaxy"]},
      {"Dry Irish Stout", :stout, :draft, "Classic low-gravity stout with roasty dryness.", "4.2",
       "1.040", "1.008", ["Pale Malt", "Roasted Barley", "Fuggle"]},
      {"Farmhouse Saison", :pale_ale, :active,
       "Rustic Belgian-style saison with peppery yeast character.", "6.5", "1.060", "1.004",
       ["Pilsner Malt", "Wheat Malt", "Saaz"]},
      {"Oatmeal Stout", :stout, :active, "Silky smooth stout with oat flakes for body.", "5.5",
       "1.056", "1.014",
       ["Pale Malt", "Oat Flakes", "Roasted Barley", "Chocolate Malt", "Fuggle"]},
      {"Mosaic Pale Ale", :pale_ale, :active, "Single-hop pale ale showcasing Mosaic.", "5.0",
       "1.050", "1.010", ["Pale Malt", "Vienna Malt", "Mosaic"]},
      {"Coffee Stout", :stout, :active, "Bold stout with locally roasted coffee beans.", "6.0",
       "1.060", "1.016",
       ["Pale Malt", "Roasted Barley", "Chocolate Malt", "Coffee Beans", "Fuggle"]},
      {"Honey Wheat", :wheat, :active, "Light wheat beer finished with local wildflower honey.",
       "5.5", "1.055", "1.012", ["Wheat Malt", "Pale Malt", "Honey", "Saaz"]},
      {"Rye IPA", :ipa, :active, "Spicy rye character meets bold American hops.", "6.2", "1.060",
       "1.010", ["Pale Malt", "Rye Malt", "Centennial", "Amarillo"]},
      {"Vienna Lager", :lager, :active, "Malty amber lager with Vienna malt backbone.", "5.0",
       "1.050", "1.012", ["Vienna Malt", "Munich Malt", "Saaz"]},
      {"Belgian Dubbel", :pale_ale, :draft, "Rich malty Belgian-style ale with dark fruit.",
       "7.5", "1.075", "1.015", ["Pilsner Malt", "Munich Malt", "Crystal 60"]},
      {"Pilsner", :lager, :active, "Classic Czech-style pilsner with Saaz hops.", "4.5", "1.045",
       "1.008", ["Pilsner Malt", "Saaz"]},
      {"Galaxy Pale Ale", :pale_ale, :active, "Australian hop-forward pale ale.", "5.2", "1.052",
       "1.010", ["Pale Malt", "Wheat Malt", "Galaxy"]},
      {"Cocoa Porter", :porter, :active, "Rich porter with cocoa nibs and vanilla.", "6.0",
       "1.060", "1.016",
       ["Pale Malt", "Crystal 60", "Chocolate Malt", "Cocoa Nibs", "Vanilla Beans"]},
      {"West Coast IPA", :ipa, :active, "Bitter, dry, and assertively hoppy West Coast classic.",
       "7.0", "1.068", "1.010", ["Pale Malt", "Centennial", "Simcoe", "Amarillo"]},
      {"Smoked Porter", :porter, :draft, "Porter with rauchmalz for subtle smokiness.", "5.5",
       "1.055", "1.013", ["Pale Malt", "Munich Malt", "Chocolate Malt", "Fuggle"]},
      {"Tropical Sour", :sour, :active, "Fruited sour with mango and passionfruit character.",
       "4.0", "1.040", "1.006", ["Wheat Malt", "Pale Malt"]},
      {"Oktoberfest", :lager, :retired, "Traditional Maerzen-style amber lager.", "5.8", "1.058",
       "1.014", ["Munich Malt", "Vienna Malt", "Saaz"]},
      {"Black IPA", :ipa, :active, "Dark but hoppy with roasted malt and citrus hops.", "6.5",
       "1.065", "1.012", ["Pale Malt", "Roasted Barley", "Cascade", "Centennial"]},
      {"Cream Ale", :pale_ale, :active, "Light, smooth, and easy-drinking American classic.",
       "4.5", "1.045", "1.008", ["Pale Malt", "Pilsner Malt", "Cascade"]},
      {"Amber Ale", :pale_ale, :active, "Balanced amber with caramel malt and moderate hops.",
       "5.3", "1.053", "1.013", ["Pale Malt", "Crystal 60", "Cascade", "Centennial"]},
      {"Imperial Stout", :stout, :draft,
       "Massive, complex stout with layers of dark malt flavor.", "10.0", "1.100", "1.020",
       ["Pale Malt", "Roasted Barley", "Chocolate Malt", "Oat Flakes", "Fuggle"]},
      {"Koelsch", :lager, :active, "Delicate German ale fermented cold for clean flavor.", "4.8",
       "1.048", "1.010", ["Pilsner Malt", "Wheat Malt", "Saaz"]},
      {"Nelson Sauvin Pale", :pale_ale, :active,
       "New Zealand hop showcase with white wine notes.", "5.5", "1.055", "1.010",
       ["Pale Malt", "Vienna Malt", "Nelson Sauvin"]},
      {"Brown Ale", :pale_ale, :retired, "Malty English-style brown with nutty character.", "5.0",
       "1.050", "1.012", ["Pale Malt", "Crystal 60", "Chocolate Malt", "Fuggle"]},
      {"Hazy DIPA", :ipa, :active, "Double dry-hopped hazy with massive tropical juice.", "8.0",
       "1.078", "1.014",
       ["Pale Malt", "Wheat Malt", "Oat Flakes", "Citra", "Galaxy", "Nelson Sauvin"]},
      {"Saison Brett", :pale_ale, :draft,
       "Saison refermented with Brettanomyces for funky complexity.", "7.0", "1.065", "1.002",
       ["Pilsner Malt", "Wheat Malt", "Saaz"]},
      {"Scotch Ale", :pale_ale, :active, "Rich, malty Scottish-style ale with caramel sweetness.",
       "8.0", "1.080", "1.018", ["Pale Malt", "Munich Malt", "Crystal 60", "Roasted Barley"]},
      {"Gose", :sour, :active, "Tart, salty wheat beer with coriander.", "4.2", "1.042", "1.008",
       ["Wheat Malt", "Pilsner Malt", "Coriander"]},
      {"Barleywine", :ipa, :draft,
       "English-style barleywine with rich malt and aged hop character.", "10.5", "1.105",
       "1.022", ["Pale Malt", "Munich Malt", "Crystal 60", "Fuggle"]},
      {"Kveik IPA", :ipa, :active, "Quick-fermenting IPA using Norwegian farmhouse yeast.", "6.0",
       "1.058", "1.008", ["Pale Malt", "Mosaic", "Citra"]},
      {"Dunkelweizen", :wheat, :active, "Dark German wheat beer with banana and clove.", "5.5",
       "1.055", "1.014", ["Wheat Malt", "Munich Malt", "Chocolate Malt"]},
      {"Breakfast Stout", :stout, :active, "Stout brewed with coffee, oats, and cocoa.", "7.0",
       "1.070", "1.018",
       ["Pale Malt", "Oat Flakes", "Roasted Barley", "Coffee Beans", "Cocoa Nibs"]},
      {"Honey Saison", :pale_ale, :active, "Farmhouse ale fermented with wildflower honey.",
       "7.5", "1.070", "1.004", ["Pilsner Malt", "Wheat Malt", "Honey", "Saaz"]},
      {"Lemon Sour", :sour, :draft, "Tart and refreshing kettle sour with lemon zest.", "3.8",
       "1.038", "1.006", ["Wheat Malt", "Pilsner Malt"]},
      {"Rum Barrel Stout", :stout, :draft, "Imperial stout aged on rum barrel chips.", "9.0",
       "1.090", "1.020", ["Pale Malt", "Roasted Barley", "Chocolate Malt", "Rum Barrel Chips"]},
      {"Blonde Ale", :pale_ale, :active, "Simple, clean, and approachable everyday beer.", "4.5",
       "1.045", "1.010", ["Pale Malt", "Cascade"]},
      {"Maerzen", :lager, :active, "Rich, malty amber lager for fall seasonal release.", "5.6",
       "1.056", "1.012", ["Munich Malt", "Vienna Malt", "Pilsner Malt", "Saaz"]},
      {"Triple IPA", :ipa, :draft, "Absurdly hoppy triple IPA for hop enthusiasts only.", "11.0",
       "1.110", "1.018", ["Pale Malt", "Munich Malt", "Citra", "Simcoe", "Mosaic", "Galaxy"]}
    ]
  end

  defp seed_batches!(recipes, staff) do
    active_recipes = Enum.filter(recipes, &(&1.status == :active))
    all_brewable = Enum.filter(recipes, &(&1.status in [:active, :draft]))
    brewers = Enum.filter(staff, &(&1.role in [:brewer, :head_brewer]))

    batches =
      for year <- [2023, 2024, 2025],
          batch_idx <- 1..batch_count_for_year(year) do
        recipe =
          Enum.random(
            if(year == 2025,
              do: all_brewable,
              else: active_recipes ++ active_recipes ++ all_brewable
            )
          )

        brewer = Enum.random(brewers)
        status = pick_status(year, batch_idx)
        batch_number = "B-#{year}-#{String.pad_leading("#{batch_idx}", 3, "0")}"

        {brew_date, pkg_date, og, fg, abv, vol} =
          batch_measurements(status, recipe, year, batch_idx)

        attrs =
          %{
            batch_number: batch_number,
            brew_date: brew_date,
            brewer_id: brewer.id,
            notes: generate_notes(status, recipe.name),
            package_date: pkg_date,
            recipe_id: recipe.id,
            status: status
          }
          |> maybe_put_decimal(:actual_og, og)
          |> maybe_put_decimal(:actual_fg, fg)
          |> maybe_put_decimal(:actual_abv, abv)
          |> maybe_put_decimal(:volume_liters, vol)

        Brewery.Batch
        |> Ash.Changeset.for_create(:create, attrs)
        |> Ash.create!(scope: @scope)
      end

    List.flatten(batches)
  end

  defp batch_count_for_year(2023), do: 80
  defp batch_count_for_year(2024), do: 120
  defp batch_count_for_year(2025), do: 60

  defp pick_status(2023, _idx), do: :complete
  defp pick_status(2024, idx) when idx <= 90, do: :complete
  defp pick_status(2024, idx) when idx <= 100, do: Enum.random([:packaging, :conditioning])
  defp pick_status(2024, idx) when idx <= 110, do: Enum.random([:fermenting, :brewing])
  defp pick_status(2024, _idx), do: Enum.random([:planned, :cancelled])
  defp pick_status(2025, idx) when idx <= 20, do: :complete
  defp pick_status(2025, idx) when idx <= 30, do: Enum.random([:packaging, :conditioning])
  defp pick_status(2025, idx) when idx <= 40, do: Enum.random([:fermenting, :brewing])
  defp pick_status(2025, idx) when idx <= 50, do: :planned
  defp pick_status(2025, _idx), do: Enum.random([:planned, :cancelled])

  defp batch_measurements(:complete, recipe, year, idx) do
    bd = random_date(year, idx)
    pd = Date.add(bd, 30 + :rand.uniform(30))
    og_val = jitter(recipe.target_og, "0.003")
    fg_val = jitter(recipe.target_fg, "0.002")
    abv_val = jitter(recipe.target_abv, "0.3")
    vol = Decimal.new("#{400 + :rand.uniform(800)}")
    {bd, pd, og_val, fg_val, abv_val, vol}
  end

  defp batch_measurements(status, _recipe, year, idx)
       when status in [:packaging, :conditioning, :fermenting, :brewing] do
    {random_date(year, idx), nil, nil, nil, nil, nil}
  end

  defp batch_measurements(_status, _recipe, _year, _idx) do
    {nil, nil, nil, nil, nil, nil}
  end

  defp random_date(year, idx) do
    month = min(div(idx - 1, 10) + 1, 12)
    day = min(rem(idx * 3, 28) + 1, 28)
    Date.new!(year, month, day)
  end

  defp jitter(nil, _range), do: nil

  defp jitter(%Decimal{} = base, range) do
    delta =
      range
      |> Decimal.new()
      |> Decimal.mult(Decimal.from_float(:rand.uniform() * 2 - 1))

    Decimal.add(base, delta) |> Decimal.round(3)
  end

  defp generate_notes(:complete, recipe), do: "#{recipe} batch completed successfully."
  defp generate_notes(:packaging, recipe), do: "#{recipe} ready for packaging."
  defp generate_notes(:conditioning, _recipe), do: "Conditioning at cellar temperature."
  defp generate_notes(:fermenting, _recipe), do: "Active fermentation in progress."
  defp generate_notes(:brewing, _recipe), do: "Brew day in progress."
  defp generate_notes(:planned, _recipe), do: "Scheduled for upcoming production."
  defp generate_notes(:cancelled, _recipe), do: "Cancelled due to scheduling conflict."

  defp seed_quality_tests!(batches, staff) do
    testers = Enum.filter(staff, &(&1.role == :quality))
    completed = Enum.filter(batches, &(&1.status == :complete))

    in_progress =
      Enum.filter(batches, &(&1.status in [:brewing, :fermenting, :conditioning, :packaging]))

    Enum.each(completed, fn batch ->
      tester = Enum.random(testers)
      taste_passed = :rand.uniform() > 0.1
      ph_value = Float.round(4.0 + :rand.uniform() * 0.4, 1)

      tests = [
        %{
          batch_id: batch.id,
          notes: "Within target range.",
          passed: true,
          result: "OG: #{batch.actual_og || "1.050"}",
          test_type: :gravity,
          tested_at: days_ago(30),
          tester_id: tester.id
        },
        %{
          batch_id: batch.id,
          notes: "Fermentation complete.",
          passed: true,
          result: "FG: #{batch.actual_fg || "1.010"}",
          test_type: :gravity,
          tested_at: days_ago(14),
          tester_id: tester.id
        },
        %{
          batch_id: batch.id,
          notes: "Within acceptable range.",
          passed: true,
          result: "pH #{ph_value}",
          test_type: :ph,
          tested_at: days_ago(14),
          tester_id: tester.id
        },
        %{
          batch_id: batch.id,
          notes: "Brilliant clarity.",
          passed: true,
          result: "Clear, good color",
          test_type: :appearance,
          tested_at: days_ago(7),
          tester_id: tester.id
        },
        %{
          batch_id: batch.id,
          notes:
            if(taste_passed, do: "Panel pass.", else: "Slight off-flavor detected, retesting."),
          passed: taste_passed,
          result: if(taste_passed, do: "Clean, balanced", else: "Off-flavor detected"),
          test_type: :taste,
          tested_at: days_ago(5),
          tester_id: tester.id
        }
      ]

      micro_test =
        if :rand.uniform() > 0.4 do
          [
            %{
              batch_id: batch.id,
              notes: "Plating clean after 48h.",
              passed: true,
              result: "No contamination detected",
              test_type: :microbiology,
              tested_at: days_ago(3),
              tester_id: tester.id
            }
          ]
        else
          []
        end

      Enum.each(tests ++ micro_test, fn attrs ->
        Brewery.QualityTest
        |> Ash.Changeset.for_create(:create, attrs)
        |> Ash.create!(scope: @scope)
      end)
    end)

    Enum.each(in_progress, fn batch ->
      tester = Enum.random(testers)
      ph_passed = :rand.uniform() > 0.3
      ph_value = Float.round(4.0 + :rand.uniform() * 1.2, 1)

      tests = [
        %{
          batch_id: batch.id,
          notes: "Initial gravity reading.",
          passed: true,
          result: "OG: 1.0#{50 + :rand.uniform(15)}",
          test_type: :gravity,
          tested_at: days_ago(2),
          tester_id: tester.id
        },
        %{
          batch_id: batch.id,
          notes: if(ph_passed, do: "Acceptable range.", else: "Slightly high, monitoring."),
          passed: ph_passed,
          result: "pH #{ph_value}",
          test_type: :ph,
          tested_at: days_ago(1),
          tester_id: tester.id
        }
      ]

      appearance_test =
        if :rand.uniform() > 0.5 do
          [
            %{
              batch_id: batch.id,
              notes: "Sample pulled for visual inspection.",
              passed: true,
              result: "Color and clarity developing",
              test_type: :appearance,
              tested_at: days_ago(1),
              tester_id: tester.id
            }
          ]
        else
          []
        end

      Enum.each(tests ++ appearance_test, fn attrs ->
        Brewery.QualityTest
        |> Ash.Changeset.for_create(:create, attrs)
        |> Ash.create!(scope: @scope)
      end)
    end)
  end

  defp days_ago(n), do: DateTime.utc_now() |> DateTime.add(-n, :day)

  defp maybe_put_decimal(map, _key, nil), do: map
  defp maybe_put_decimal(map, key, %Decimal{} = val), do: Map.put(map, key, val)
end
