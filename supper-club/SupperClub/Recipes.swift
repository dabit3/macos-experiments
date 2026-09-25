import Foundation

enum Recipes {
  static let all: [Recipe] = [
    Recipe(
      id: "tomato-orzo", title: "Burst tomato\n& basil orzo",
      subtitle: "Jammy tomatoes. A little butter. A very good Tuesday.",
      minutes: 25, servings: 2, label: "Vegetarian", style: 0,
      ingredients: [
        Ingredient(name: "Orzo", quantity: 180, unit: "g"),
        Ingredient(name: "Cherry tomatoes", quantity: 300, unit: "g"),
        Ingredient(name: "Garlic", quantity: 2, unit: "cloves", note: "thinly sliced"),
        Ingredient(name: "Olive oil", quantity: 1, unit: "tbsp"),
        Ingredient(name: "Butter", quantity: 20, unit: "g"),
        Ingredient(name: "Basil", quantity: 10, unit: "g"),
        Ingredient(name: "Lemon", quantity: 0.5, unit: ""),
        Ingredient(name: "Salt", quantity: 0.5, unit: "tsp"),
      ],
      steps: [
        CookStep(
          title: "A little prep",
          instruction:
            "Halve the tomatoes. Slice the garlic and tear the basil leaves. Bring a large pan of water to a boil; add half the measured salt."
        ),
        CookStep(
          title: "Let them burst",
          instruction:
            "Warm the oil in a wide skillet over medium heat. Add tomatoes and the remaining salt. Cook for 8 minutes, stirring gently, until juicy and collapsing. Add garlic for the final minute.",
          timerName: "Tomatoes", seconds: 480),
        CookStep(
          title: "Orzo, al dente",
          instruction:
            "Meanwhile, boil the orzo for the time on its packet, usually 8–10 minutes. Set this timer to your packet time. Reserve a mug of the cooking water, then drain.",
          timerName: "Orzo", seconds: 540),
        CookStep(
          title: "Bring it together",
          instruction:
            "Stir orzo, butter and a splash of reserved water into the tomatoes over low heat. Stir for 1 minute until glossy. Add more water a little at a time if needed.",
          timerName: "Glossy finish", seconds: 60),
        CookStep(
          title: "The finishing touch",
          instruction:
            "Turn off the heat. Squeeze in the lemon and fold through the basil. Taste before adding any more salt. Spoon into warm bowls and bring straight to the table."
        ),
      ]),
    Recipe(
      id: "chickpea-toast", title: "Smoky chickpeas\non toast",
      subtitle: "Crisp edges, warm spice, cool lemon yogurt.",
      minutes: 15, servings: 2, label: "Vegetarian", style: 1,
      ingredients: [
        Ingredient(name: "Chickpeas", quantity: 240, unit: "g", note: "cooked, drained"),
        Ingredient(name: "Sourdough", quantity: 2, unit: "slices"),
        Ingredient(name: "Greek yogurt", quantity: 100, unit: "g"),
        Ingredient(name: "Smoked paprika", quantity: 0.5, unit: "tsp"),
        Ingredient(name: "Olive oil", quantity: 1, unit: "tbsp"),
        Ingredient(name: "Lemon", quantity: 0.5, unit: ""),
        Ingredient(name: "Parsley", quantity: 5, unit: "g"),
        Ingredient(name: "Salt", quantity: 0.25, unit: "tsp"),
      ],
      steps: [
        CookStep(
          title: "Make lemon yogurt",
          instruction:
            "Stir the yogurt with a squeeze of lemon and half the salt. Roughly chop the parsley. Drain and pat the chickpeas dry."
        ),
        CookStep(
          title: "Wake up the spice",
          instruction:
            "Heat oil in a skillet over medium heat. Add chickpeas and remaining salt. Cook for 5 minutes, shaking often. Lower the heat, add paprika and stir for 30 seconds.",
          timerName: "Chickpeas", seconds: 300),
        CookStep(
          title: "Toast & tumble",
          instruction:
            "Toast the sourdough until crisp and golden. Spread each slice with lemon yogurt and pile on the warm chickpeas."
        ),
        CookStep(
          title: "Finish generously",
          instruction:
            "Scatter over parsley and squeeze over the remaining lemon. Eat with a knife and fork while the toast is crisp."
        ),
      ]),
    Recipe(
      id: "mushroom-rice", title: "Miso mushrooms\n& sesame rice",
      subtitle: "Deeply savory, with a bright tangle of spring onion.",
      minutes: 30, servings: 2, label: "Vegan", style: 2,
      ingredients: [
        Ingredient(name: "Jasmine rice", quantity: 150, unit: "g"),
        Ingredient(name: "Mushrooms", quantity: 300, unit: "g", note: "thickly sliced"),
        Ingredient(name: "White miso", quantity: 1, unit: "tbsp"),
        Ingredient(name: "Soy sauce", quantity: 1, unit: "tbsp"),
        Ingredient(name: "Maple syrup", quantity: 1, unit: "tsp"),
        Ingredient(name: "Olive oil", quantity: 1, unit: "tbsp"),
        Ingredient(name: "Spring onions", quantity: 2, unit: ""),
        Ingredient(name: "Sesame seeds", quantity: 1, unit: "tsp"),
      ],
      steps: [
        CookStep(
          title: "Start the rice",
          instruction:
            "Rinse the rice. Add to a saucepan with 225 ml water for 2 servings (scale the water with your servings). Bring to a boil, cover, reduce to low and cook for 12 minutes. Follow packet guidance if it differs.",
          timerName: "Rice", seconds: 720),
        CookStep(
          title: "Give it a rest",
          instruction:
            "Turn off the heat and leave the rice covered for 5 minutes. Mix miso, soy sauce and maple syrup with a splash of water.",
          timerName: "Rice rest", seconds: 300),
        CookStep(
          title: "Brown the mushrooms",
          instruction:
            "Heat oil in a wide skillet over medium-high heat. Cook mushrooms for 7–9 minutes, stirring occasionally, until browned. Work in batches for more than 2 servings.",
          timerName: "Mushrooms", seconds: 480),
        CookStep(
          title: "Glaze & serve",
          instruction:
            "Lower the heat. Pour the miso mixture over the mushrooms and toss for 1 minute until glossy. Fluff rice into bowls, add mushrooms and scatter with sliced spring onions and sesame.",
          timerName: "Miso glaze", seconds: 60),
      ]),
    Recipe(
      id: "lemon-lentils", title: "Lemony lentils\nwith roast carrots",
      subtitle: "A warm salad that earns its place at dinner.",
      minutes: 35, servings: 2, label: "Vegan", style: 3,
      ingredients: [
        Ingredient(name: "Carrots", quantity: 400, unit: "g"),
        Ingredient(name: "Green lentils", quantity: 300, unit: "g", note: "cooked, drained"),
        Ingredient(name: "Olive oil", quantity: 2, unit: "tbsp"),
        Ingredient(name: "Lemon", quantity: 1, unit: ""),
        Ingredient(name: "Ground cumin", quantity: 0.5, unit: "tsp"),
        Ingredient(name: "Parsley", quantity: 10, unit: "g"),
        Ingredient(name: "Salt", quantity: 0.5, unit: "tsp"),
      ],
      steps: [
        CookStep(
          title: "Heat & slice",
          instruction:
            "Heat the oven to 220°C / 425°F (200°C fan). Cut carrots into finger-size batons. Toss with half the oil, cumin and half the salt on a baking tray."
        ),
        CookStep(
          title: "Roast until tender",
          instruction:
            "Roast for 25 minutes, turning halfway, until a knife slides in easily and the edges are golden. Use a second tray for larger batches.",
          timerName: "Carrots", seconds: 1500),
        CookStep(
          title: "Warm the lentils",
          instruction:
            "Put cooked lentils in a saucepan with a splash of water. Warm over medium-low heat for 4 minutes, stirring. Drain any excess water.",
          timerName: "Lentils", seconds: 240),
        CookStep(
          title: "Dress at the table",
          instruction:
            "Whisk remaining oil, lemon juice and remaining salt. Toss with warm lentils and chopped parsley. Top with the carrots. Taste and adjust lemon to your liking."
        ),
      ]),
    Recipe(
      id: "pea-pasta", title: "Green pea\n& lemon linguine",
      subtitle: "A silky green sauce, made from freezer favorites.",
      minutes: 20, servings: 2, label: "Vegetarian", style: 4,
      ingredients: [
        Ingredient(name: "Linguine", quantity: 180, unit: "g"),
        Ingredient(name: "Frozen peas", quantity: 200, unit: "g"),
        Ingredient(name: "Crème fraîche", quantity: 60, unit: "g"),
        Ingredient(name: "Lemon", quantity: 0.5, unit: ""),
        Ingredient(name: "Mint", quantity: 5, unit: "g"),
        Ingredient(name: "Salt", quantity: 0.5, unit: "tsp"),
      ],
      steps: [
        CookStep(
          title: "Get the water going",
          instruction:
            "Boil a large pot of water and add the salt. Cook linguine following packet time, usually 10 minutes. Adjust the timer to match.",
          timerName: "Linguine", seconds: 600),
        CookStep(
          title: "A quick green sauce",
          instruction:
            "In a second pan, boil peas for 3 minutes. Reserve a cup of their water, then drain. Blend three quarters of the peas with crème fraîche, mint, lemon zest and a splash of the reserved water.",
          timerName: "Peas", seconds: 180),
        CookStep(
          title: "Toss until silky",
          instruction:
            "Reserve a mug of pasta water before draining. Return pasta to the pot off the heat. Stir in pea sauce and whole peas, loosening with pasta water."
        ),
        CookStep(
          title: "Brighten it up",
          instruction:
            "Squeeze in lemon juice. Taste for salt. Divide between bowls and finish with torn mint if you have a little left."
        ),
      ]),
    Recipe(
      id: "salmon-tray", title: "Mustard salmon\n& crisp potatoes",
      subtitle: "One tray, a sharp dressing, almost no washing up.",
      minutes: 40, servings: 2, label: "Fish", style: 5,
      ingredients: [
        Ingredient(name: "Salmon", quantity: 2, unit: "fillets", note: "about 150 g each"),
        Ingredient(name: "Baby potatoes", quantity: 400, unit: "g"),
        Ingredient(name: "Green beans", quantity: 200, unit: "g"),
        Ingredient(name: "Dijon mustard", quantity: 1, unit: "tbsp"),
        Ingredient(name: "Olive oil", quantity: 1, unit: "tbsp"),
        Ingredient(name: "Lemon", quantity: 0.5, unit: ""),
        Ingredient(name: "Salt", quantity: 0.5, unit: "tsp"),
      ],
      steps: [
        CookStep(
          title: "Potatoes go first",
          instruction:
            "Heat oven to 220°C / 425°F (200°C fan). Halve potatoes. Toss with oil and salt on a tray; roast cut-side down for 25 minutes.",
          timerName: "Potatoes", seconds: 1500),
        CookStep(
          title: "Brush the salmon",
          instruction:
            "Mix mustard with lemon juice. Pat salmon dry and brush with the mixture. Trim green beans."
        ),
        CookStep(
          title: "Everything on the tray",
          instruction:
            "Turn potatoes. Add salmon and beans beside them. Roast for 12–15 minutes, until salmon reaches 63°C / 145°F in its thickest part. Timing varies with thickness; use a thermometer.",
          timerName: "Salmon", seconds: 780),
        CookStep(
          title: "Supper is ready",
          instruction:
            "Check potatoes are tender and salmon is cooked through. Divide onto warm plates. Spoon the tray juices over the beans."
        ),
      ]),
    Recipe(
      id: "butter-beans", title: "Tomato-braised\nbutter beans",
      subtitle: "Slow-supper comfort, on a weeknight clock.",
      minutes: 25, servings: 2, label: "Vegan", style: 6,
      ingredients: [
        Ingredient(name: "Butter beans", quantity: 480, unit: "g", note: "cooked, drained"),
        Ingredient(name: "Canned tomatoes", quantity: 400, unit: "g"),
        Ingredient(name: "Garlic", quantity: 2, unit: "cloves"),
        Ingredient(name: "Olive oil", quantity: 1, unit: "tbsp"),
        Ingredient(name: "Spinach", quantity: 100, unit: "g"),
        Ingredient(name: "Smoked paprika", quantity: 0.5, unit: "tsp"),
        Ingredient(name: "Salt", quantity: 0.25, unit: "tsp"),
      ],
      steps: [
        CookStep(
          title: "Build the base",
          instruction:
            "Slice garlic. Heat oil in a saucepan over medium-low heat. Soften garlic for 1 minute without browning. Stir in paprika.",
          timerName: "Garlic", seconds: 60),
        CookStep(
          title: "Let it simmer",
          instruction:
            "Add tomatoes and salt. Break tomatoes up with a spoon. Simmer uncovered over medium-low heat for 10 minutes, stirring occasionally.",
          timerName: "Tomato sauce", seconds: 600),
        CookStep(
          title: "Beans in",
          instruction:
            "Stir in drained butter beans. Simmer gently for 5 minutes until hot throughout; add water if the sauce is thick.",
          timerName: "Butter beans", seconds: 300),
        CookStep(
          title: "A handful of green",
          instruction:
            "Stir in spinach until wilted, about 1 minute. Taste for salt and serve in shallow bowls. Bread is lovely alongside, if you have it."
        ),
      ]),
    Recipe(
      id: "chicken-couscous", title: "Herby chicken\n& lemon couscous",
      subtitle: "Golden pan chicken meets a fluffy, fragrant side.",
      minutes: 30, servings: 2, label: "Chicken", style: 7,
      ingredients: [
        Ingredient(name: "Chicken breast", quantity: 300, unit: "g"),
        Ingredient(name: "Couscous", quantity: 140, unit: "g"),
        Ingredient(name: "Olive oil", quantity: 1, unit: "tbsp"),
        Ingredient(name: "Lemon", quantity: 1, unit: ""),
        Ingredient(name: "Parsley", quantity: 10, unit: "g"),
        Ingredient(name: "Ground cumin", quantity: 0.5, unit: "tsp"),
        Ingredient(name: "Salt", quantity: 0.5, unit: "tsp"),
      ],
      steps: [
        CookStep(
          title: "Season the chicken",
          instruction:
            "Slice chicken horizontally into even, thin cutlets. Coat with oil, cumin and half the salt. Wash hands and clean the board after handling raw chicken."
        ),
        CookStep(
          title: "Golden on both sides",
          instruction:
            "Heat a skillet over medium heat. Cook chicken for about 4–5 minutes per side, until its thickest part reaches 74°C / 165°F. Use a thermometer; time alone cannot confirm doneness.",
          timerName: "Chicken — turn halfway", seconds: 600),
        CookStep(
          title: "Fluff the couscous",
          instruction:
            "Put couscous and remaining salt in a heatproof bowl. Add 175 ml boiling water for 2 servings (scale with servings), or follow packet ratio. Cover for 5 minutes.",
          timerName: "Couscous", seconds: 300),
        CookStep(
          title: "Rest, then serve",
          instruction:
            "Rest cooked chicken for 3 minutes. Fluff couscous with a fork, lemon juice and chopped parsley. Slice chicken on a clean board and lay on top.",
          timerName: "Chicken rest", seconds: 180),
      ]),
    Recipe(
      id: "sweet-potato", title: "Roast sweet potato\n& tahini",
      subtitle: "Caramelized wedges, peppery leaves, a generous drizzle.",
      minutes: 40, servings: 2, label: "Vegan", style: 8,
      ingredients: [
        Ingredient(name: "Sweet potatoes", quantity: 500, unit: "g"),
        Ingredient(name: "Chickpeas", quantity: 240, unit: "g", note: "cooked, drained"),
        Ingredient(name: "Tahini", quantity: 2, unit: "tbsp"),
        Ingredient(name: "Lemon", quantity: 0.5, unit: ""),
        Ingredient(name: "Olive oil", quantity: 1, unit: "tbsp"),
        Ingredient(name: "Rocket", quantity: 40, unit: "g"),
        Ingredient(name: "Salt", quantity: 0.5, unit: "tsp"),
      ],
      steps: [
        CookStep(
          title: "Cut into wedges",
          instruction:
            "Heat oven to 220°C / 425°F (200°C fan). Scrub sweet potatoes and cut into 2 cm wedges. Pat drained chickpeas dry."
        ),
        CookStep(
          title: "Roast together",
          instruction:
            "Toss wedges and chickpeas with oil and half the salt on a tray. Roast for 30 minutes, turning halfway, until wedges are soft inside and golden outside.",
          timerName: "Sweet potato", seconds: 1800),
        CookStep(
          title: "The tahini drizzle",
          instruction:
            "Whisk tahini, lemon juice and remaining salt. Add cold water a little at a time until pourable, about 2 tablespoons for 2 servings. It may seize at first; keep whisking.",
          timerName: "Whisk dressing", seconds: 30),
        CookStep(
          title: "Pile high",
          instruction:
            "Divide rocket between plates. Add warm wedges and chickpeas, then spoon over the dressing. Serve immediately."
        ),
      ]),
    Recipe(
      id: "pepper-eggs", title: "Soft eggs\nin pepper sauce",
      subtitle: "A little smoky, a little sweet. Best shared from the pan.",
      minutes: 30, servings: 2, label: "Vegetarian", style: 9,
      ingredients: [
        Ingredient(name: "Eggs", quantity: 4, unit: ""),
        Ingredient(name: "Red pepper", quantity: 1, unit: ""),
        Ingredient(name: "Canned tomatoes", quantity: 400, unit: "g"),
        Ingredient(name: "Garlic", quantity: 2, unit: "cloves"),
        Ingredient(name: "Olive oil", quantity: 1, unit: "tbsp"),
        Ingredient(name: "Smoked paprika", quantity: 0.5, unit: "tsp"),
        Ingredient(name: "Parsley", quantity: 5, unit: "g"),
        Ingredient(name: "Salt", quantity: 0.5, unit: "tsp"),
      ],
      steps: [
        CookStep(
          title: "Soften the pepper",
          instruction:
            "Thinly slice pepper and garlic. Warm oil in a lidded skillet over medium heat. Cook pepper for 7 minutes until soft, then stir in garlic and paprika.",
          timerName: "Peppers", seconds: 420),
        CookStep(
          title: "Make the sauce",
          instruction:
            "Add tomatoes and salt. Simmer uncovered for 10 minutes until thickened, breaking up tomatoes with a spoon.",
          timerName: "Pepper sauce", seconds: 600),
        CookStep(
          title: "Nestle in the eggs",
          instruction:
            "Make a hollow for each egg. Crack eggs into the hollows. Cover and cook on low for 6–9 minutes, until whites are fully set and yolks reach your preferred firmness. For vulnerable diners, cook yolks firm.",
          timerName: "Eggs", seconds: 480),
        CookStep(
          title: "Bring the pan",
          instruction:
            "Scatter chopped parsley over the eggs. Set the pan on a trivet and serve at once. For fractional eggs when scaling, beat an egg and use the portion needed, or round up."
        ),
      ]),
  ]
}
