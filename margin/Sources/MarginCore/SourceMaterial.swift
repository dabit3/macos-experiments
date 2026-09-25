import Foundation

public struct SourcePage: Sendable {
  public let eyebrow: String
  public let title: String
  public let subtitle: String
  public let paragraphs: [String]
  public let pullQuote: String
}

public enum SourceMaterial {
  public static let title = "The attentive city"
  public static let pages: [SourcePage] = [
    SourcePage(
      eyebrow: "01 / THE HUMAN SCALE",
      title: "The attentive\ncity",
      subtitle: "Notes on streets, stillness & public life",
      paragraphs: [
        "A city is more than a system for moving people. It is a setting for noticing one another. Its smallest spaces — the doorstep, the shaded bench, the corner shop — can shape the texture of ordinary life.",
        "When a street makes room for lingering, it makes room for belonging. This is not a claim that every road should become a plaza. It is an invitation to ask whose time a place values, and what kinds of presence it welcomes.",
        "These field notes explore three design practices: slowing the pace of movement, creating comfortable edges, and observing public life before drawing conclusions. The aim is a street that works at the speed of attention.",
      ],
      pullQuote: "A good street offers more than a route.\nIt offers a reason to remain."
    ),
    SourcePage(
      eyebrow: "02 / A DIFFERENT MEASURE",
      title: "Design for\nthe pause",
      subtitle: "What the traffic count leaves out",
      paragraphs: [
        "Throughput is easy to count. A person crossing a square can be reduced to a moving dot. Yet the most meaningful use of a place may be the person who stops: to greet a neighbor, read a notice, or watch the afternoon change.",
        "A pause is not a failure of movement. It is evidence that a place has become a destination. Designing for that pause means giving people somewhere to sit without buying anything, and enough room to stand without being in the way.",
        "Comfort is cumulative. Shade extends a conversation. A low wall becomes an informal seat. A crossing that feels safe allows a child to walk at their own pace. No single intervention guarantees a lively street, but each can remove a reason to leave.",
        "Evaluation should therefore include stationary activity alongside movement. Count how many people stay, where they choose to wait, and whether different ages can share the same edge. Repeat these observations at different hours.",
      ],
      pullQuote: "Count the people who stay,\nnot only the people who pass."
    ),
    SourcePage(
      eyebrow: "03 / THE SOCIAL EDGE",
      title: "Small places,\nshared life",
      subtitle: "The architecture of a chance encounter",
      paragraphs: [
        "The edge between a building and a street is a place of negotiation. A blank wall asks nothing of a passerby. A window, a shallow stoop, or a planted threshold offers something to notice and a reason to slow down.",
        "Public life often begins at the edges. People prefer places where they can see activity without standing in its center. A seat with a protected back and an open view supports both participation and retreat.",
        "Good edges also make different uses compatible. A wide threshold can hold a delivery, a short conversation, and someone resting, without forcing them into the path of others. This generosity is spatial, but its consequences are social.",
        "A useful design question is not simply how much open space exists, but how many ways there are to inhabit it. Offer a choice of sun and shade, solitude and company, short stops and longer stays.",
      ],
      pullQuote: "Belonging is built from small,\nrepeatable invitations."
    ),
    SourcePage(
      eyebrow: "04 / OBSERVE, THEN ADAPT",
      title: "A patient\nmethod",
      subtitle: "Learning from the street as it is",
      paragraphs: [
        "Begin with observation rather than a rendering. Walk the street at the pace of its slowest users. Record where people hesitate, improvise a seat, seek shade, or take an unexpected route. These adaptations are design information.",
        "A useful field study separates observation from interpretation. Write down what happened before deciding why. Three people standing beneath one tree is an observation; a need for more shade is a hypothesis to test.",
        "Small, reversible changes can turn that hypothesis into a question the street can answer. Move a bench. Widen a waiting area with temporary furniture. Return at comparable times and note what changes, including who is still missing.",
        "Listening should accompany counting. Ask residents which places feel welcoming, and which ordinary tasks remain difficult. A design that improves a visitor's afternoon may still complicate a resident's daily routine.",
      ],
      pullQuote: "Treat every intervention as a question,\nand public life as part of the answer."
    ),
    SourcePage(
      eyebrow: "05 / FROM NOTES TO ACTION",
      title: "Make room\nfor attention",
      subtitle: "A working brief for an ordinary street",
      paragraphs: [
        "Start with one block and one clear question. For example: can a shaded sitting area make the walk between the bus stop and the shops more comfortable? Define the people and everyday activities the change should support.",
        "Before changing the space, record a baseline: movement, stationary activity, access needs, and the weather. After the change, repeat the same method. Keep notes on unintended effects as carefully as desired ones.",
        "A successful street does not require everyone to use it in the same way. It allows people to move, rest, work, and meet without making one activity erase another. The goal is a richer range of ordinary possibilities.",
        "The attentive city is a practice, not a finished image. Its design begins in noticing, continues through careful experiments, and remains open to revision by the people who live there.",
      ],
      pullQuote: "Design begins in noticing.\nIt earns its value in daily use."
    ),
  ]
}
