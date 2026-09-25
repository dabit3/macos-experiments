import SwiftUI

struct ExpenseEditor: View {
  let store: TripStore
  let expense: Expense?
  @Environment(\.dismiss) private var dismiss
  @State private var title: String
  @State private var amount: String
  @State private var payer: String
  @State private var participants: Set<String>
  @State private var category: Category
  @State private var custom: Bool
  @State private var customAmounts: [String: String]
  @State private var validation: String?
  @State private var deleteConfirmation = false
  @FocusState private var focused: String?

  init(store: TripStore, expense: Expense?) {
    self.store = store
    self.expense = expense
    _title = State(initialValue: expense?.title ?? "")
    _amount = State(initialValue: expense.map { Money.edit($0.amount) } ?? "")
    _payer = State(initialValue: expense?.payer ?? "you")
    _participants = State(
      initialValue: Set(expense?.participants ?? store.ledger.travelers.map(\.id)))
    _category = State(initialValue: expense?.category ?? .food)
    _custom = State(initialValue: expense?.customShares != nil)
    _customAmounts = State(initialValue: expense?.customShares?.mapValues { Money.edit($0) } ?? [:])
  }

  var body: some View {
    NavigationStack {
      ScrollView {
        VStack(alignment: .leading, spacing: 25) {
          VStack(alignment: .leading, spacing: 10) {
            Eyebrow(text: "A memory, shared")
            Text(expense == nil ? "What’s the occasion?" : "Fine-tune the details.")
              .font(.system(size: 29, design: .serif)).tracking(-1)
            TextField("e.g. Lunch by the river", text: $title)
              .font(.system(size: 18, weight: .medium))
              .padding(16).background(.white, in: RoundedRectangle(cornerRadius: 14))
              .focused($focused, equals: "title").submitLabel(.done)
              .accessibilityLabel("Expense title").accessibilityIdentifier("expenseTitle")
          }
          VStack(alignment: .leading, spacing: 8) {
            Eyebrow(text: "Amount · EUR")
            HStack(alignment: .firstTextBaseline, spacing: 8) {
              Text("€").foregroundStyle(Palette.coral)
              TextField("0.00", text: $amount).keyboardType(.decimalPad)
                .focused($focused, equals: "amount")
                .accessibilityLabel("Amount in euros").accessibilityIdentifier("expenseAmount")
            }
            .font(.system(size: 47, weight: .medium, design: .rounded)).monospacedDigit()
            Divider().overlay(Palette.line)
          }
          VStack(alignment: .leading, spacing: 12) {
            Eyebrow(text: "Category")
            HStack(spacing: 6) {
              ForEach(Category.allCases, id: \.self) { item in
                Button {
                  category = item
                  focused = nil
                } label: {
                  VStack(spacing: 7) {
                    Image(systemName: item.symbol).font(.system(size: 18))
                    Text(item.rawValue).font(.system(size: 9, weight: .semibold))
                  }
                  .frame(maxWidth: .infinity).frame(height: 62)
                  .foregroundStyle(category == item ? .white : Palette.plum)
                  .background(
                    category == item ? Palette.plum : .white, in: RoundedRectangle(cornerRadius: 13)
                  )
                }.buttonStyle(.plain).accessibilityAddTraits(category == item ? .isSelected : [])
              }
            }
          }
          VStack(alignment: .leading, spacing: 12) {
            Eyebrow(text: "Who paid?")
            HStack(spacing: 0) {
              ForEach(store.ledger.travelers) { person in
                Button {
                  payer = person.id
                  focused = nil
                } label: {
                  VStack(spacing: 7) {
                    PersonAvatar(person: person, size: 43)
                      .padding(4)
                      .overlay(
                        Circle().stroke(payer == person.id ? Palette.plum : .clear, lineWidth: 2))
                    Text(person.name).font(
                      .system(size: 12, weight: payer == person.id ? .bold : .regular))
                  }.frame(maxWidth: .infinity)
                }.buttonStyle(.plain).accessibilityLabel("Payer \(person.name)")
                  .accessibilityAddTraits(payer == person.id ? .isSelected : [])
              }
            }
          }
          VStack(alignment: .leading, spacing: 14) {
            HStack {
              Eyebrow(text: "Split between")
              Spacer()
              Text("\(participants.count) of 4").font(.system(size: 11)).foregroundStyle(
                Palette.muted)
            }
            Picker("Split method", selection: $custom) {
              Text("Equally").tag(false)
              Text("Custom amounts").tag(true)
            }.pickerStyle(.segmented).onChange(of: custom) { _, selected in
              if selected { seedCustomAmounts() }
              focused = nil
            }
            VStack(spacing: 0) {
              ForEach(store.ledger.travelers) { person in
                HStack(spacing: 11) {
                  Button {
                    if participants.contains(person.id) {
                      participants.remove(person.id)
                    } else {
                      participants.insert(person.id)
                    }
                    focused = nil
                  } label: {
                    HStack(spacing: 11) {
                      Image(
                        systemName: participants.contains(person.id)
                          ? "checkmark.circle.fill" : "circle"
                      )
                      .foregroundStyle(
                        participants.contains(person.id) ? Palette.plum : Palette.muted
                      )
                      .font(.system(size: 22))
                      Text(person.name).font(.system(size: 14, weight: .medium))
                      Spacer(minLength: 0)
                    }.frame(minHeight: 48).contentShape(Rectangle())
                  }.buttonStyle(.plain)
                    .accessibilityLabel(
                      "\(participants.contains(person.id) ? "Exclude" : "Include") \(person.name) in split"
                    )
                  if custom && participants.contains(person.id) {
                    HStack(spacing: 3) {
                      Text("€").foregroundStyle(Palette.muted)
                      TextField(
                        "0.00",
                        text: Binding(
                          get: { customAmounts[person.id] ?? "" },
                          set: { customAmounts[person.id] = $0 })
                      )
                      .keyboardType(.decimalPad).multilineTextAlignment(.trailing)
                      .focused($focused, equals: person.id)
                      .accessibilityLabel("Custom share for \(person.name)")
                    }.font(.system(size: 14, weight: .semibold, design: .rounded))
                      .padding(.horizontal, 10).frame(width: 105, height: 38)
                      .background(Palette.cream, in: RoundedRectangle(cornerRadius: 8))
                  } else {
                    Text(participants.contains(person.id) ? equalShare(person.id) : "Not included")
                      .font(.system(size: 12, weight: .medium, design: .rounded)).monospacedDigit()
                      .foregroundStyle(Palette.muted)
                  }
                }
                if person.id != store.ledger.travelers.last?.id { Divider().overlay(Palette.line) }
              }
            }.padding(.horizontal, 15).padding(.vertical, 5).background(
              .white, in: RoundedRectangle(cornerRadius: 15))
            if custom {
              Text(customSummary).font(.system(size: 12, weight: .medium))
                .foregroundStyle(customRemaining == 0 ? Palette.green : Palette.coral)
            } else {
              Text("Odd cents go in traveler ID order, so the total always matches.")
                .font(.system(size: 11)).foregroundStyle(Palette.muted)
            }
          }
          if let validation {
            Label(validation, systemImage: "exclamationmark.circle")
              .font(.system(size: 13)).foregroundStyle(Color(hex: 0xA23D30))
              .padding(14).frame(maxWidth: .infinity, alignment: .leading)
              .background(Palette.coral.opacity(0.12), in: RoundedRectangle(cornerRadius: 12))
              .accessibilityIdentifier("validationError")
          }
          if expense != nil {
            Button("Delete expense", role: .destructive) { deleteConfirmation = true }
              .font(.system(size: 14, weight: .medium)).frame(maxWidth: .infinity).frame(height: 44)
          }
        }.padding(24)
      }
      .scrollIndicators(.hidden).scrollDismissesKeyboard(.interactively)
      .background(Palette.cream)
      .foregroundStyle(Palette.plum)
      .safeAreaInset(edge: .bottom) {
        PrimaryButton(title: expense == nil ? "Add expense" : "Save changes", icon: "checkmark") {
          save()
        }
        .padding(.horizontal, 24).padding(.vertical, 10).background(Palette.cream)
      }
      .navigationTitle(expense == nil ? "New expense" : "Edit expense")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .topBarLeading) {
          Button("Cancel") { dismiss() }.foregroundStyle(Palette.plum)
        }
        ToolbarItemGroup(placement: .keyboard) {
          Spacer()
          Button("Done") { focused = nil }
        }
      }
      .confirmationDialog(
        "Delete this expense?", isPresented: $deleteConfirmation, titleVisibility: .visible
      ) {
        Button("Delete expense", role: .destructive) {
          if let expense, store.delete(expense) { dismiss() }
        }
        Button("Keep expense", role: .cancel) {}
      } message: {
        Text("Balances will recalculate. You can undo this from the trip.")
      }
      .alert(
        "Check this expense",
        isPresented: Binding(
          get: { validation != nil },
          set: { if !$0 { validation = nil } })
      ) {
        Button("OK") { validation = nil }
      } message: {
        Text(validation ?? "")
      }
    }
    .tint(Palette.plum)
  }

  private func equalShare(_ id: String) -> String {
    guard let total = try? Money.parse(amount), !participants.isEmpty else { return "—" }
    let preview = Expense(
      title: title, amount: total, payer: payer, participants: participants.sorted(),
      category: category)
    return Money.format((try? preview.shares()[id]) ?? 0)
  }

  private var customRemaining: Int? {
    guard let total = try? Money.parse(amount) else { return nil }
    var allocated = 0
    for id in participants {
      guard let share = try? Money.parse(customAmounts[id] ?? "0", allowZero: true) else {
        return nil
      }
      allocated += share
    }
    return total - allocated
  }

  private var customSummary: String {
    guard let remaining = customRemaining else {
      return "Enter a valid amount for each included traveler."
    }
    if remaining == 0 { return "Perfect. Every cent has a place." }
    return remaining > 0
      ? "\(Money.format(remaining)) left to assign" : "\(Money.format(-remaining)) over the total"
  }

  private func seedCustomAmounts() {
    guard customAmounts.isEmpty, let total = try? Money.parse(amount), !participants.isEmpty else {
      return
    }
    let preview = Expense(
      title: title, amount: total, payer: payer, participants: participants.sorted(),
      category: category)
    customAmounts = ((try? preview.shares()) ?? [:]).mapValues { Money.edit($0) }
  }

  private func save() {
    focused = nil
    do {
      let cleanTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
      guard !cleanTitle.isEmpty, cleanTitle.count <= 80, !participants.isEmpty else {
        throw LedgerError.invalidExpense
      }
      let total = try Money.parse(amount)
      var shares: [String: Int]?
      if custom {
        var result: [String: Int] = [:]
        for id in participants {
          result[id] = try Money.parse(customAmounts[id] ?? "0", allowZero: true)
        }
        shares = result
      }
      let result = Expense(
        id: expense?.id ?? UUID(), title: cleanTitle, amount: total, payer: payer,
        participants: participants.sorted(), customShares: shares, category: category,
        date: expense?.date ?? Date())
      _ = try result.shares()
      if store.save(result) { dismiss() } else { validation = store.error }
    } catch { validation = error.localizedDescription }
  }
}
