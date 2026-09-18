import Foundation

enum Recipes {
  static let all: [Recipe] = [
    Recipe(
      id: "pomodoro", title: "Sunday\npomodoro", subtitle: "A little patience. A very good pasta.",
      category: "THE COMFORT CLASSIC", minutes: 30, baseServings: 2,
      story: "Sweet tomatoes, good olive oil, torn basil. A small ritual worth slowing down for.",
      ingredients: [
        ingredient("pasta", "Rigatoni", 200, "g", "or your favorite short pasta"),
        ingredient("tomatoes", "Cherry tomatoes", 400, "g", "halved"),
        ingredient("oil", "Extra-virgin olive oil", 2, "tbsp", "plus a little to finish"),
        ingredient("garlic", "Garlic", 2, "cloves", "thinly sliced"),
        ingredient("basil", "Fresh basil", 0.5, "cup", "loosely packed, leaves torn"),
        ingredient("parmesan", "Parmesan", 30, "g", "finely grated"),
        ingredient("salt", "Fine salt", 0.5, "tsp", "for sauce; salt pasta water to taste"),
      ],
      steps: [
        step(
          "Set the table.\nThen the water.",
          "Bring a large pot of water to a rolling boil. Salt it generously. Set out a wide skillet and have your prepared ingredients within reach.",
          "A spacious pan helps the tomatoes soften evenly.", "Water check", 300),
        step(
          "Let the tomatoes\nbecome a sauce.",
          "Warm the olive oil over medium-low heat. Add garlic for 30 seconds, then tomatoes and the measured salt. Cook gently for 12 minutes, stirring and pressing the tomatoes as they soften.",
          "Keep the garlic pale. Golden is lovely; dark is bitter.", "Tomato sauce", 720),
        step(
          "Cook the pasta\njust shy of done.",
          "Add rigatoni to the boiling water. Cook for 10 minutes, or 1 minute less than your packet recommends. Before draining, reserve a mug of the starchy cooking water.",
          "Your packet is the authority: pasta shapes cook differently.", "Rigatoni", 600),
        step(
          "Bring it all\ntogether.",
          "Add drained pasta to the sauce with a splash of pasta water. Toss over medium heat for 1–2 minutes until glossy. Remove from heat and fold in half the basil and Parmesan.",
          "Add water a spoonful at a time. The sauce should cling, not pool.", "Final toss", 120),
        step(
          "Dinner,\nbeautifully done.",
          "Divide between warm bowls. Finish with the remaining basil, Parmesan and a little olive oil. Taste before adding any extra salt, and serve right away.",
          "Leave the pan at the table for the last delicious spoonful.", nil, nil),
      ],
      substitutions: [
        Substitution(
          original: "No cherry tomatoes?",
          alternative:
            "Use the same weight of canned whole tomatoes, crushed by hand. Simmer 5 minutes longer."
        ),
        Substitution(
          original: "Make it plant-based",
          alternative: "Swap Parmesan for toasted breadcrumbs and a little nutritional yeast."),
        Substitution(
          original: "Gluten-free",
          alternative: "Use gluten-free rigatoni and follow its packet timing."),
      ]),
    Recipe(
      id: "salmon", title: "Lemon butter\nsalmon",
      subtitle: "Golden edges. Bright, buttery comfort.",
      category: "ONE PAN, ALL JOY", minutes: 25, baseServings: 2,
      story: "Crisp-skinned salmon with green beans, lemon and a quick pan butter.",
      ingredients: [
        ingredient("salmon", "Salmon fillets", 2, "", "150 g each, skin on"),
        ingredient("beans", "Green beans", 250, "g", "trimmed"),
        ingredient("butter", "Unsalted butter", 30, "g", "cubed"),
        ingredient("lemon", "Lemon", 1, "", "half juiced, half sliced"),
        ingredient("oil", "Olive oil", 1, "tbsp", ""),
        ingredient("salt", "Fine salt", 0.5, "tsp", ""),
        ingredient("parsley", "Parsley", 2, "tbsp", "chopped"),
      ],
      steps: [
        step(
          "A little prep.",
          "Pat salmon thoroughly dry and season with salt. Trim beans. Bring a saucepan of water to a boil.",
          "Dry fish gives you a better crust.", nil, nil),
        step(
          "Blanch the greens.",
          "Boil green beans for 4 minutes until tender with a little bite, then drain well.",
          "Taste one before draining.", "Green beans", 240),
        step(
          "Skin side down.",
          "Heat oil in a skillet over medium-high heat. Place salmon skin side down and press gently for 20 seconds. Cook for 5 minutes without moving it.",
          "Lower the heat if the oil smokes.", "Crisp salmon", 300),
        step(
          "Butter & lemon.",
          "Turn the salmon. Reduce heat and add butter and lemon juice. Baste for 3–4 minutes, until the thickest part reaches 63°C / 145°F. Add beans to warm through.",
          "Time is a guide; verify fish doneness with a food thermometer.", "Salmon finish", 240),
        step(
          "Serve something lovely.",
          "Plate salmon and beans. Spoon over lemon butter and scatter with parsley. Serve with lemon slices.",
          "For a fuller dinner, add bread or cooked potatoes.", nil, nil),
      ],
      substitutions: [
        Substitution(
          original: "Different greens",
          alternative: "Use asparagus instead of green beans; blanch 2–3 minutes."),
        Substitution(
          original: "Dairy-free",
          alternative: "Replace butter with olive oil. Finish with extra lemon zest."),
      ]),
    Recipe(
      id: "risotto", title: "Woodland\nrisotto", subtitle: "Slow stirring. Deep, earthy flavor.",
      category: "A SLOW EVENING", minutes: 40, baseServings: 2,
      story: "Golden mushrooms folded through silky rice. A quiet, hands-on supper.",
      ingredients: [
        ingredient("rice", "Arborio rice", 160, "g", ""),
        ingredient("mushroom", "Mixed mushrooms", 250, "g", "sliced"),
        ingredient("stock", "Vegetable stock", 750, "ml", "kept hot"),
        ingredient("shallot", "Shallot", 1, "", "finely diced"),
        ingredient("oil", "Olive oil", 1, "tbsp", ""),
        ingredient("butter", "Unsalted butter", 25, "g", ""),
        ingredient("parmesan", "Parmesan", 35, "g", "finely grated"),
        ingredient("thyme", "Thyme leaves", 1, "tsp", ""),
      ],
      steps: [
        step(
          "Warm the stock.",
          "Bring stock to a gentle simmer in a saucepan. Keep it warm over low heat. Prepare the shallot and mushrooms.",
          "Hot stock keeps the rice cooking steadily.", nil, nil),
        step(
          "Golden mushrooms.",
          "Heat olive oil in a wide pan. Cook mushrooms over medium-high heat for 7 minutes until golden. Stir in thyme, then transfer half the mushrooms to a plate.",
          "Give mushrooms space and let their moisture evaporate.", "Mushrooms", 420),
        step(
          "Toast the rice.",
          "Lower heat to medium. Add half the butter and the shallot. Cook 3 minutes, then add rice and stir for 2 minutes until its edges look translucent.",
          "Toasting coats the grains without browning them.", "Toast rice", 120),
        step(
          "One ladle at a time.",
          "Add a ladle of hot stock. Stir often until mostly absorbed, then add another. Repeat for about 20 minutes until rice is tender with a slight bite. You may not need every drop.",
          "If stock runs out before rice is cooked, use hot water.", "Risotto", 1200),
        step(
          "The final fold.",
          "Off the heat, fold in the remaining butter and Parmesan. Add stock to loosen if needed. Rest 2 minutes. Taste for salt and top with the reserved mushrooms.",
          "Risotto should spread gently on the plate.", "Rest", 120),
      ],
      substitutions: [
        Substitution(
          original: "No Arborio?",
          alternative: "Carnaroli rice works beautifully. Avoid long-grain rice here."),
        Substitution(
          original: "Plant-based bowl",
          alternative: "Use olive oil instead of butter and a plant-based Parmesan alternative."),
      ]),
    Recipe(
      id: "chickpeas", title: "Crispy chickpea\nharvest bowl",
      subtitle: "Color, crunch and a tahini drizzle.",
      category: "PLANTS AT THEIR BEST", minutes: 35, baseServings: 2,
      story: "Spiced chickpeas and sweet potato over tender grains with a lemony dressing.",
      ingredients: [
        ingredient("chickpeas", "Cooked chickpeas", 240, "g", "drained and dried"),
        ingredient("potato", "Sweet potato", 300, "g", "cut in 2 cm cubes"),
        ingredient("quinoa", "Dry quinoa", 120, "g", "rinsed"),
        ingredient("water", "Water", 240, "ml", "for the quinoa"),
        ingredient("oil", "Olive oil", 2, "tbsp", ""),
        ingredient("paprika", "Smoked paprika", 1, "tsp", ""),
        ingredient("salt", "Fine salt", 0.5, "tsp", ""),
        ingredient("tahini", "Tahini", 2, "tbsp", ""),
        ingredient("lemon", "Lemon juice", 1, "tbsp", ""),
        ingredient("greens", "Baby spinach", 60, "g", ""),
      ],
      steps: [
        step(
          "Turn up the oven.",
          "Heat oven to 220°C / 425°F. Pat chickpeas dry. Toss chickpeas and sweet potato with olive oil, paprika and salt on a large baking tray.",
          "Spread everything in one layer for crisp edges.", nil, nil),
        step(
          "Roast until golden.",
          "Roast for 25 minutes, turning halfway through, until sweet potato is tender and chickpeas are crisp at the edges.",
          "If crowded, use two trays and switch them halfway.", "Roast vegetables", 1500),
        step(
          "Fluffy quinoa.",
          "Combine rinsed quinoa and the measured water. Bring to a boil, cover and reduce to low for 15 minutes. Remove from heat and rest, covered, for 5 minutes.",
          "Keep the lid on while the grains steam.", "Quinoa", 900),
        step(
          "Make the drizzle.",
          "Whisk tahini and lemon juice. Add water 1 teaspoon at a time until pourable. Taste and adjust with a pinch of salt if needed.",
          "Tahini thickens at first, then turns silky as you add water.", nil, nil),
        step(
          "Build your bowl.",
          "Fluff quinoa. Divide spinach and quinoa among bowls. Add roasted sweet potato and chickpeas, then spoon over the dressing.",
          "Let hot vegetables soften the spinach just a little.", nil, nil),
      ],
      substitutions: [
        Substitution(
          original: "Sesame-free dressing",
          alternative: "Use plain yogurt with lemon and a little water instead of tahini."),
        Substitution(
          original: "A different grain",
          alternative: "Use cooked brown rice instead of quinoa; follow its packet method."),
      ]),
    Recipe(
      id: "pancakes", title: "Blueberry\nmorning pancakes", subtitle: "A slow start, stacked high.",
      category: "WEEKEND RITUAL", minutes: 20, baseServings: 2,
      story: "Tender buttermilk pancakes with juicy berries and a generous pour of maple.",
      ingredients: [
        ingredient("flour", "Plain flour", 125, "g", ""),
        ingredient("powder", "Baking powder", 1, "tsp", ""),
        ingredient("sugar", "Caster sugar", 1, "tbsp", ""),
        ingredient("salt", "Fine salt", 0.25, "tsp", ""),
        ingredient("egg", "Egg", 1, "", "beat before dividing when scaling"),
        ingredient("milk", "Buttermilk", 180, "ml", ""),
        ingredient("butter", "Butter", 20, "g", "melted, plus a little for the pan"),
        ingredient("berries", "Blueberries", 100, "g", ""),
        ingredient("maple", "Maple syrup", 2, "tbsp", "to serve"),
      ],
      steps: [
        step(
          "Dry meets wet.",
          "Whisk flour, baking powder, sugar and salt in a bowl. In another bowl, whisk egg, buttermilk and melted butter.",
          "Let melted butter cool slightly before adding egg.", nil, nil),
        step(
          "Keep it lumpy.",
          "Fold wet ingredients into dry just until no dry flour remains. Fold in half the blueberries. Rest batter for 5 minutes.",
          "A few lumps are good. Overmixing makes pancakes tough.", "Batter rest", 300),
        step(
          "The first side.",
          "Warm a non-stick pan over medium-low heat and lightly butter it. Spoon about 3 tablespoons of batter per pancake. Cook for 2 minutes, until bubbles appear and edges set.",
          "Cook in batches; leave room to flip.", "First side", 120),
        step(
          "Flip, then repeat.",
          "Flip and cook another 1–2 minutes until golden and the center is set with no wet batter. Repeat with remaining batter. Adjust heat if pancakes brown too quickly.",
          "Keep finished pancakes warm in a low oven.", "Second side", 120),
        step(
          "Make a morning of it.",
          "Stack warm pancakes. Scatter over the remaining blueberries and drizzle with maple syrup. Serve immediately.",
          "Makes about 6 small pancakes at 2 servings.", nil, nil),
      ],
      substitutions: [
        Substitution(
          original: "No buttermilk?",
          alternative:
            "Mix the same volume of milk with 1 tsp lemon juice per 180 ml. Rest 5 minutes."),
        Substitution(
          original: "Frozen berries",
          alternative:
            "Add them straight from frozen; do not thaw. Cooking may take a little longer."),
      ]),
  ]

  private static func ingredient(
    _ id: String, _ name: String, _ amount: Double, _ unit: String, _ note: String
  ) -> Ingredient {
    Ingredient(id: id, name: name, amount: amount, unit: unit, note: note)
  }

  private static func step(
    _ title: String, _ instruction: String, _ tip: String, _ timer: String?, _ seconds: Int?
  ) -> CookingStep {
    CookingStep(
      title: title, instruction: instruction, tip: tip, timerName: timer, timerSeconds: seconds)
  }
}
