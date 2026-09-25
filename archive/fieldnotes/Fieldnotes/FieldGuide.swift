import Foundation

struct GuideSubject: Identifiable {
  let id: String
  let name: String
  let latin: String
  let category: SpecimenCategory
  let habitat: String
  let marks: String
  let invitation: String
  let range: String

  static let all: [GuideSubject] = [
    .init(
      id: "fern", name: "Lady fern", latin: "Athyrium filix-femina", category: .plants,
      habitat: "Damp, shaded woodland and stream edges.",
      marks:
        "Feathery fronds with finely divided leaflets. Young fronds emerge as curled fiddleheads.",
      invitation: "Follow one frond from its stem to its tip. How many smaller patterns repeat?",
      range: "Temperate Northern Hemisphere"),
    .init(
      id: "oak", name: "English oak", latin: "Quercus robur", category: .plants,
      habitat: "Woodland, hedgerows and open parkland.",
      marks: "Rounded leaf lobes and short leaf stalks. Acorns hang on longer stalks in autumn.",
      invitation:
        "Look for the tiny ears at the base of a leaf. Sketch its outline without picking it.",
      range: "Europe; planted elsewhere"),
    .init(
      id: "daisy", name: "Common daisy", latin: "Bellis perennis", category: .plants,
      habitat: "Short grass, lawns and well-trodden meadows.",
      marks:
        "A yellow disc surrounded by white rays, sometimes tipped pink. Spoon-shaped leaves hug the ground.",
      invitation: "Watch a flower head as clouds pass. Are its rays open or folded?",
      range: "Europe; widely naturalized"),
    .init(
      id: "dandelion", name: "Dandelion", latin: "Taraxacum officinale group", category: .plants,
      habitat: "Lawns, verges and disturbed ground.",
      marks:
        "Golden flower heads on hollow, leafless stalks. Deeply toothed leaves grow in a basal rosette.",
      invitation: "Find a flower and a seed head nearby. Record two stages of the same story.",
      range: "Widespread in temperate regions"),
    .init(
      id: "clover", name: "Red clover", latin: "Trifolium pratense", category: .plants,
      habitat: "Meadows, grasslands and road verges.",
      marks: "Rounded pink-purple flower heads. Three oval leaflets often carry a pale chevron.",
      invitation: "Wait beside a patch. Which insects visit, and how long do they stay?",
      range: "Europe and Asia; widely naturalized"),
    .init(
      id: "robin", name: "American robin", latin: "Turdus migratorius", category: .birds,
      habitat: "Gardens, lawns and open woodland.",
      marks:
        "A thrush with a rusty orange breast, gray-brown back and yellow bill. Often runs, then pauses on lawns.",
      invitation: "Notice the rhythm of its movement. Record what it does before it finds food.",
      range: "North America"),
    .init(
      id: "tit", name: "Great tit", latin: "Parus major", category: .birds,
      habitat: "Woodland, parks and gardens.",
      marks:
        "Black head, white cheeks and a yellow belly split by a dark stripe. Listen for repeated two-note calls.",
      invitation: "Describe its song with your own syllables. Does the rhythm repeat?",
      range: "Europe and parts of Asia"),
    .init(
      id: "butterfly", name: "Monarch butterfly", latin: "Danaus plexippus", category: .insects,
      habitat: "Open meadows and gardens, especially near milkweed.",
      marks:
        "Orange wings crossed with black veins, edged in black with white dots. Similar butterflies exist.",
      invitation:
        "Watch from a distance. Record which flower it chooses and how it holds its wings.",
      range: "Primarily the Americas; established elsewhere"),
    .init(
      id: "ladybird", name: "Seven-spot ladybird", latin: "Coccinella septempunctata",
      category: .insects,
      habitat: "Gardens, meadows and crops with aphids.",
      marks: "Red wing cases with seven black spots in total; black head with pale patches.",
      invitation: "Count the spots without handling it. Look for aphids on the same plant.",
      range: "Europe and Asia; introduced to North America"),
    .init(
      id: "snail", name: "Garden snail", latin: "Cornu aspersum", category: .other,
      habitat: "Damp gardens, hedges and sheltered walls.",
      marks:
        "A rounded, mottled brown spiral shell and two pairs of tentacles. Most active in mild, damp weather.",
      invitation: "Follow its trail with your eyes. What textures does it cross?",
      range: "Mediterranean origin; widely introduced"),
    .init(
      id: "mushroom", name: "Fly agaric", latin: "Amanita muscaria", category: .fungi,
      habitat: "Often near birch, pine and spruce trees.",
      marks:
        "Red to orange cap, often with white patches; pale gills and a ring on the stem. Rain can wash patches away.",
      invitation: "Observe without touching or collecting. Note nearby trees and cap shape.",
      range: "Temperate and boreal Northern Hemisphere"),
    .init(
      id: "turkey", name: "Turkey tail", latin: "Trametes versicolor", category: .fungi,
      habitat: "Dead hardwood logs, stumps and branches.",
      marks:
        "Thin, overlapping fans with concentric colored bands. Many similar bracket fungi occur.",
      invitation: "Trace the bands in a sketch. How many colors can you distinguish?",
      range: "Widespread worldwide"),
  ]

  static func find(_ id: String?) -> GuideSubject? { all.first { $0.id == id } }
}
