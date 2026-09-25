import SwiftUI
import UIKit

enum TripTab: String, CaseIterable {
  case trip = "Trip"
  case balances = "Balances"
  case insights = "Insights"

  var symbol: String {
    switch self {
    case .trip: "square.stack"
    case .balances: "arrow.left.arrow.right"
    case .insights: "chart.pie"
    }
  }
}

struct ExpenseRoute: Identifiable {
  let id = UUID()
  let expense: Expense?
}

struct ExportRoute: Identifiable {
  let id = UUID()
  let url: URL
}

struct TripView: View {
  @Bindable var store: TripStore
  @State private var tab = TripTab.trip
  @State private var editor: ExpenseRoute?
  @State private var payment: Transfer?
  @State private var resetConfirmation = false
  @State private var export: ExportRoute?

  var body: some View {
    VStack(spacing: 0) {
      header
      ScrollView {
        VStack(alignment: .leading, spacing: 24) {
          if store.loadFailed {
            Text(
              "Saved trip unavailable. Restore the example from the menu to continue. Your original file will be preserved."
            )
            .font(.subheadline).padding().background(
              .yellow.opacity(0.2), in: RoundedRectangle(cornerRadius: 12))
          }
          switch tab {
          case .trip: tripContent
          case .balances: balanceContent
          case .insights: insightsContent
          }
          if let notice = store.notice {
            HStack {
              Image(systemName: "checkmark.circle.fill")
              Text(notice)
              Spacer()
              if store.previous != nil {
                Button("Undo") { store.undo() }.fontWeight(.bold)
              }
            }
            .font(.caption)
            .foregroundStyle(Palette.green)
            .padding(14)
            .background(Color.white, in: RoundedRectangle(cornerRadius: 14))
            .accessibilityIdentifier("notice")
          }
          Text("Made for memories. Settled in cents.")
            .font(.system(size: 11, design: .serif)).italic()
            .foregroundStyle(Palette.muted)
            .frame(maxWidth: .infinity).padding(.bottom, 8)
        }
        .padding(.horizontal, 24).padding(.top, 10)
      }
      .scrollIndicators(.hidden)
      bottomBar
    }
    .background(Palette.cream)
    .foregroundStyle(Palette.plum)
    .sheet(item: $editor) { route in ExpenseEditor(store: store, expense: route.expense) }
    .sheet(item: $export) { ActivitySheet(url: $0.url).presentationDetents([.medium, .large]) }
    .confirmationDialog(
      "Record this payment?",
      isPresented: Binding(get: { payment != nil }, set: { if !$0 { payment = nil } }),
      titleVisibility: .visible
    ) {
      if let payment {
        Button("Record \(Money.format(payment.amount)) received") {
          _ = store.change({ try $0.record(payment) }, notice: "Payment recorded")
          self.payment = nil
        }
      }
      Button("Cancel", role: .cancel) { payment = nil }
    } message: {
      if let payment {
        Text(
          "\(store.ledger.name(payment.from)) → \(store.ledger.name(payment.to)). Only record a payment that happened outside Fairshare. No money is moved."
        )
      }
    }
    .confirmationDialog(
      "Restore the Lisbon example?", isPresented: $resetConfirmation, titleVisibility: .visible
    ) {
      Button("Restore example trip", role: .destructive) { store.reset() }
      Button("Cancel", role: .cancel) {}
    } message: {
      Text(
        "Replace this ledger with the original five expenses. You can undo this until the app closes."
      )
    }
    .alert(
      "Couldn’t complete that",
      isPresented: Binding(get: { store.error != nil }, set: { if !$0 { store.error = nil } })
    ) {
      Button("OK") { store.error = nil }
    } message: {
      Text(store.error ?? "")
    }
  }

  private var header: some View {
    HStack(spacing: 8) {
      ZStack {
        Capsule().fill(Palette.coral).frame(width: 10, height: 24).rotationEffect(.degrees(38))
          .offset(x: -4)
        Capsule().fill(Palette.plum).frame(width: 10, height: 24).rotationEffect(.degrees(38))
          .offset(x: 6)
      }.frame(width: 26)
      Text("fairshare").font(.system(size: 22, weight: .semibold, design: .rounded)).tracking(-1)
      Spacer()
      if store.previous != nil {
        Button {
          store.undo()
        } label: {
          Image(systemName: "arrow.uturn.backward").frame(width: 42, height: 42)
        }.accessibilityLabel("Undo last change")
      }
      Menu {
        Button("Export ledger CSV", systemImage: "square.and.arrow.up") {
          if let url = store.export() { export = ExportRoute(url: url) }
        }
        Button("Restore example trip", systemImage: "arrow.counterclockwise", role: .destructive) {
          resetConfirmation = true
        }
      } label: {
        Image(systemName: "ellipsis").font(.system(size: 19, weight: .medium))
          .frame(width: 42, height: 42)
          .background(.white.opacity(0.8), in: Circle())
      }.accessibilityLabel("Trip options")
    }
    .padding(.horizontal, 24).padding(.top, 6).padding(.bottom, 14)
  }

  private var tripContent: some View {
    Group {
      VStack(alignment: .leading, spacing: 8) {
        Eyebrow(text: "Portugal / 06 — 10 Sep 2026")
        Text("Lisbon, together.").font(.system(size: 35, weight: .regular, design: .serif))
          .tracking(-1.5)
      }
      VStack(spacing: 0) {
        LisbonArt().frame(height: 150)
        HStack(spacing: 0) {
          HStack(spacing: -9) {
            ForEach(store.ledger.travelers) { person in
              PersonAvatar(person: person, size: 28).overlay(
                Circle().stroke(Palette.cream, lineWidth: 2))
            }
          }
          Spacer()
          Text("Four friends, one good trip.").font(.system(size: 11, weight: .medium))
        }
        .padding(.horizontal, 15).padding(.vertical, 12).background(Color(hex: 0xF0EBDf))
      }
      .clipShape(RoundedRectangle(cornerRadius: 21))
      HStack(alignment: .bottom) {
        VStack(alignment: .leading, spacing: 6) {
          Eyebrow(text: "Trip total")
          Text(Money.format(store.ledger.total)).font(
            .system(size: 35, weight: .medium, design: .rounded)
          ).tracking(-1.5).monospacedDigit().minimumScaleFactor(0.6)
        }
        Spacer()
        VStack(alignment: .trailing, spacing: 6) {
          Text("Your share").font(.system(size: 12)).foregroundStyle(Palette.muted)
          Text(Money.format(store.yourShare)).font(
            .system(size: 20, weight: .semibold, design: .rounded)
          ).monospacedDigit()
        }.padding(.bottom, 3)
      }
      VStack(spacing: 0) {
        HStack {
          Text("The trip ledger").font(.system(size: 21, design: .serif))
          Spacer()
          Text(
            "\(store.ledger.expenses.count) \(store.ledger.expenses.count == 1 ? "expense" : "expenses")"
          ).font(.system(size: 11)).foregroundStyle(
            Palette.muted)
        }.padding(.bottom, 15)
        if store.ledger.expenses.isEmpty {
          emptyState(
            "A fresh page.", detail: "Add the first expense. We’ll take care of the split.",
            icon: "square.and.pencil")
        } else {
          ForEach(store.ledger.expenses.sorted { $0.date > $1.date }) { expense in
            Button {
              editor = ExpenseRoute(expense: expense)
            } label: {
              expenseRow(expense)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(
              "\(expense.title), \(Money.format(expense.amount)), paid by \(store.ledger.name(expense.payer)). Edit expense"
            )
            if expense.id != store.ledger.expenses.sorted(by: { $0.date > $1.date }).last?.id {
              Divider().overlay(Palette.line).padding(.leading, 56)
            }
          }
        }
      }
    }
  }

  private func expenseRow(_ expense: Expense) -> some View {
    HStack(spacing: 12) {
      Image(systemName: expense.category.symbol)
        .font(.system(size: 18, weight: .regular))
        .frame(width: 42, height: 46)
        .background(Palette.color(expense.category), in: RoundedRectangle(cornerRadius: 13))
      VStack(alignment: .leading, spacing: 5) {
        Text(expense.title).font(.system(size: 14, weight: .semibold)).lineLimit(1)
        Text("\(store.ledger.name(expense.payer)) paid · \(expense.participants.count) people")
          .font(.system(size: 11)).foregroundStyle(Palette.muted)
      }
      Spacer(minLength: 3)
      Text(Money.format(expense.amount)).font(
        .system(size: 14, weight: .semibold, design: .rounded)
      ).monospacedDigit()
      Image(systemName: "chevron.right").font(.system(size: 9, weight: .bold)).foregroundStyle(
        Palette.muted)
    }
    .padding(.vertical, 12).contentShape(Rectangle())
  }

  private var balanceContent: some View {
    Group {
      VStack(alignment: .leading, spacing: 8) {
        Eyebrow(text: "A little clarity")
        Text("All even, eventually.").font(.system(size: 33, design: .serif)).tracking(-1.5)
        Text("Good trips don’t leave loose ends.").font(.system(size: 13)).foregroundStyle(
          Palette.muted)
      }
      VStack(alignment: .leading, spacing: 16) {
        HStack {
          Eyebrow(text: "Your balance")
          Spacer()
          Image(
            systemName: store.balances["you", default: 0] == 0
              ? "checkmark.circle" : "arrow.down.left")
        }
        Text(Money.format(abs(store.balances["you", default: 0])))
          .font(.system(size: 44, weight: .medium, design: .rounded)).monospacedDigit().tracking(-2)
        Text(
          store.balances["you", default: 0] > 0
            ? "You’re owed. We’ve done the math."
            : store.balances["you", default: 0] < 0
              ? "You owe. A few taps to keep track." : "You’re all square. Enjoy the memories."
        )
        .font(.system(size: 12))
      }
      .foregroundStyle(Palette.plum)
      .padding(22).frame(maxWidth: .infinity, alignment: .leading)
      .background(Palette.lilac.opacity(0.55), in: RoundedRectangle(cornerRadius: 23))

      VStack(alignment: .leading, spacing: 18) {
        HStack {
          Text("Where everyone stands").font(.system(size: 20, design: .serif))
          Spacer()
        }
        HStack {
          Text("OWES").foregroundStyle(Palette.coral)
          Spacer()
          Text("IS OWED").foregroundStyle(Palette.green)
        }.font(.system(size: 9, weight: .bold, design: .monospaced)).tracking(1.5)
        ForEach(store.ledger.travelers) { person in
          balanceRow(person)
        }
        HStack(spacing: 5) {
          Image(systemName: "equal.circle")
          Text("Every cent accounted for · net €0.00")
        }.font(.system(size: 10)).foregroundStyle(Palette.muted)
      }
      VStack(alignment: .leading, spacing: 12) {
        HStack {
          Text("The shortest way home").font(.system(size: 21, design: .serif))
          Spacer()
          Text("\(store.plan.count)").font(.system(size: 12, weight: .bold))
            .frame(width: 25, height: 25).background(Palette.line, in: Circle())
        }
        Text("A simplified plan. Record only payments already made.")
          .font(.system(size: 11)).foregroundStyle(Palette.muted)
        if store.plan.isEmpty {
          emptyState(
            "Beautifully balanced.", detail: "Everyone is settled. Here’s to the next trip.",
            icon: "checkmark.seal")
        } else {
          ForEach(store.plan) { transfer in
            VStack(spacing: 14) {
              HStack {
                Text("\(store.ledger.name(transfer.from))").fontWeight(.semibold)
                Image(systemName: "arrow.right").foregroundStyle(Palette.muted)
                Text(store.ledger.name(transfer.to)).fontWeight(.semibold)
                Spacer()
                Text(Money.format(transfer.amount)).fontWeight(.bold).monospacedDigit()
              }.font(.system(size: 14))
              Button {
                payment = transfer
              } label: {
                HStack {
                  Text("Record payment")
                  Spacer()
                  Image(systemName: "arrow.up.right")
                }
                .font(.system(size: 12, weight: .semibold))
                .padding(.vertical, 12).padding(.horizontal, 14)
                .background(Palette.cream, in: RoundedRectangle(cornerRadius: 10))
              }
              .accessibilityLabel(
                "Record \(store.ledger.name(transfer.from)) paying \(store.ledger.name(transfer.to)) \(Money.format(transfer.amount))"
              )
            }
            .padding(16).background(.white, in: RoundedRectangle(cornerRadius: 18))
          }
        }
      }
      if !store.ledger.transfers.isEmpty {
        VStack(alignment: .leading, spacing: 14) {
          Eyebrow(text: "Recorded payments")
          ForEach(store.ledger.transfers.reversed()) { transfer in
            HStack {
              Image(systemName: "checkmark.circle.fill").foregroundStyle(Palette.green)
              Text("\(store.ledger.name(transfer.from)) → \(store.ledger.name(transfer.to))")
              Spacer()
              Text(Money.format(transfer.amount)).monospacedDigit()
            }.font(.system(size: 12))
          }
        }
      }
    }
  }

  private func balanceRow(_ person: Traveler) -> some View {
    let balance = store.balances[person.id, default: 0]
    let maximum = max(store.balances.values.map { abs($0) }.max() ?? 1, 1)
    return HStack(spacing: 10) {
      PersonAvatar(person: person, size: 32)
      Text(person.name).font(.system(size: 12, weight: .medium)).frame(
        width: 40, alignment: .leading)
      GeometryReader { geometry in
        let half = geometry.size.width / 2
        let width = max(balance == 0 ? 0 : 3, half * CGFloat(abs(balance)) / CGFloat(maximum))
        ZStack(alignment: .leading) {
          Rectangle().fill(Palette.line).frame(width: 1).offset(x: half)
          Capsule().fill(balance < 0 ? Palette.coral : Palette.green)
            .frame(width: width, height: 9)
            .offset(x: balance < 0 ? half - width : half)
        }
      }.frame(height: 25)
      Text(balance == 0 ? "€0.00" : "\(balance > 0 ? "+" : "−")\(Money.format(abs(balance)))")
        .font(.system(size: 12, weight: .semibold, design: .rounded)).monospacedDigit()
        .foregroundStyle(balance < 0 ? Palette.coral : Palette.green)
        .frame(width: 85, alignment: .trailing)
    }
    .accessibilityElement(children: .ignore)
    .accessibilityLabel(
      "\(person.name) \(balance < 0 ? "owes" : "is owed") \(Money.format(abs(balance)))")
  }

  private var insightsContent: some View {
    Group {
      VStack(alignment: .leading, spacing: 8) {
        Eyebrow(text: "The shape of your trip")
        Text("Worth every memory.").font(.system(size: 32, design: .serif)).tracking(-1.4)
        Text("A little perspective on what you shared.").font(.system(size: 13)).foregroundStyle(
          Palette.muted)
      }
      ZStack {
        Circle().stroke(Palette.line, lineWidth: 32)
        ForEach(Array(Category.allCases.enumerated()), id: \.element) { index, category in
          Circle()
            .trim(from: arcStart(index), to: arcStart(index) + arcFraction(category))
            .stroke(categoryAccent(category), style: StrokeStyle(lineWidth: 32, lineCap: .butt))
            .rotationEffect(.degrees(-90))
        }
        VStack(spacing: 8) {
          Eyebrow(text: "Together")
          Text(Money.format(store.ledger.total)).font(
            .system(size: 30, weight: .medium, design: .rounded)
          ).tracking(-1).monospacedDigit()
          Text(
            "\(store.ledger.expenses.count) shared \(store.ledger.expenses.count == 1 ? "moment" : "moments")"
          ).font(.system(size: 11))
            .foregroundStyle(Palette.muted)
        }
      }.frame(width: 228, height: 228).frame(maxWidth: .infinity).padding(.vertical, 24)
        .accessibilityElement(children: .ignore).accessibilityLabel(
          "Category breakdown of \(Money.format(store.ledger.total)) in expenses")
      VStack(spacing: 20) {
        ForEach(Category.allCases, id: \.self) { category in
          let total = categoryTotal(category)
          let count = store.ledger.expenses.filter { $0.category == category }.count
          HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 4).fill(categoryAccent(category)).frame(
              width: 10, height: 30)
            VStack(alignment: .leading, spacing: 4) {
              Text(category.rawValue).font(.system(size: 14, weight: .semibold))
              Text("\(count) \(count == 1 ? "expense" : "expenses")")
                .font(.system(size: 11)).foregroundStyle(Palette.muted)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 4) {
              Text(Money.format(total)).font(.system(size: 15, weight: .semibold, design: .rounded))
                .monospacedDigit()
              Text(
                "\(store.ledger.total == 0 ? 0 : Int((Double(total) / Double(store.ledger.total) * 100).rounded()))% of trip"
              )
              .font(.system(size: 10)).foregroundStyle(Palette.muted)
            }
          }
        }
      }.padding(22).background(.white, in: RoundedRectangle(cornerRadius: 21))
      VStack(alignment: .leading, spacing: 10) {
        Image(systemName: "quote.opening").foregroundStyle(Palette.coral)
        Text("Collect moments.\nWe’ll keep the receipts.").font(.system(size: 26, design: .serif))
          .tracking(-0.5)
        Text(
          "All amounts in EUR. Payments are tracked separately and never increase your trip total."
        )
        .font(.system(size: 12)).foregroundStyle(Palette.muted).lineSpacing(4)
      }.padding(.vertical, 5)
      PrimaryButton(title: "Export trip ledger", icon: "square.and.arrow.up") {
        if let url = store.export() { export = ExportRoute(url: url) }
      }
    }
  }

  private func categoryTotal(_ category: Category) -> Int {
    store.ledger.expenses.filter { $0.category == category }.reduce(0) { $0 + $1.amount }
  }

  private func categoryAccent(_ category: Category) -> Color {
    switch category {
    case .stay: Palette.plum
    case .food: Palette.coral
    case .travel: Palette.green
    case .experiences: Palette.lilac
    }
  }

  private func arcFraction(_ category: Category) -> CGFloat {
    CGFloat(categoryTotal(category)) / CGFloat(max(store.ledger.total, 1))
  }

  private func arcStart(_ index: Int) -> CGFloat {
    Category.allCases.prefix(index).reduce(CGFloat(0)) { $0 + arcFraction($1) }
  }

  private var bottomBar: some View {
    VStack(spacing: 12) {
      if tab == .trip {
        PrimaryButton(title: "Add an expense") { editor = ExpenseRoute(expense: nil) }
          .padding(.horizontal, 24).padding(.top, 10)
      }
      HStack(spacing: 0) {
        ForEach(TripTab.allCases, id: \.self) { item in
          Button {
            withAnimation(.easeInOut(duration: 0.18)) { tab = item }
          } label: {
            HStack(spacing: 8) {
              Image(systemName: item.symbol).font(.system(size: 16))
              Text(item.rawValue).font(
                .system(size: 12, weight: tab == item ? .semibold : .regular))
            }
            .foregroundStyle(tab == item ? Palette.plum : Palette.muted)
            .frame(maxWidth: .infinity).frame(height: 45)
            .background(tab == item ? Palette.line.opacity(0.75) : .clear, in: Capsule())
          }.buttonStyle(.plain).accessibilityAddTraits(tab == item ? .isSelected : [])
        }
      }.padding(.horizontal, 16).padding(.bottom, 3)
    }
    .background(Palette.cream.shadow(color: Palette.plum.opacity(0.04), radius: 15, y: -5))
  }

  private func emptyState(_ title: String, detail: String, icon: String) -> some View {
    VStack(spacing: 10) {
      Image(systemName: icon).font(.system(size: 27)).foregroundStyle(Palette.green)
      Text(title).font(.system(size: 22, design: .serif))
      Text(detail).font(.system(size: 12)).foregroundStyle(Palette.muted).multilineTextAlignment(
        .center)
    }.frame(maxWidth: .infinity).padding(26).background(
      .white, in: RoundedRectangle(cornerRadius: 18))
  }
}

struct ActivitySheet: UIViewControllerRepresentable {
  let url: URL
  func makeUIViewController(context: Context) -> UIActivityViewController {
    UIActivityViewController(activityItems: [url], applicationActivities: nil)
  }
  func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}
