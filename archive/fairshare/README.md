# Fairshare

![Fairshare screenshot](screenshots/fairshare.jpg)

A native iPhone trip ledger for the small, human side of shared money. An illustrated
Lisbon getaway opens with four friends, five editable expenses, and a settlement plan
computed from the actual ledger. Cream, plum, coral and periwinkle frame an original
resolution-independent Lisbon illustration drawn in SwiftUI Canvas.

## Prerequisites

- Native macOS with Xcode 26.6 (tested toolchain: Swift 6.3.3).
- An installed iOS Simulator runtime. Developed for iPhone; iOS deployment target 18.0.
- No package downloads, generator, account, signing identity, API key or backend.
- Portrait iPhone layout. This is not an iPad-specific app.

The checked-in `Fairshare.xcodeproj` opens directly in Xcode. Choose the Fairshare
scheme and an iPhone Simulator, then Run. No project generation is necessary.

From this directory:

```sh
bash scripts/check.sh
bash scripts/build.sh
xcrun simctl list devices available
bash scripts/run.sh <your-iPhone-Simulator-UUID>
```

Build product: `build/Build/Products/Debug-iphonesimulator/Fairshare.app`.
This is an unsigned **Simulator-only** app, not a physical-iPhone or App Store release.
`run.sh` installs an existing build; run `build.sh` again after source changes.

## The app

- **Trip:** total spending, your exact allocated share, and the editable expense ledger.
  Tap any expense to edit its title, amount, category, payer, participants or split.
- **Add an expense:** title, decimal EUR amount, one payer, and one or more participants.
  Payers can be excluded from sharing an expense. Tap a traveler in the split list to
  include/exclude them. Choose equal shares or explicit custom EUR amounts.
- **Balances:** diverging bars distinguish who owes from who is owed. The simplified
  payment plan updates immediately after each edit. Record only a payment already
  made elsewhere; Fairshare never moves money.
- **Insights:** actual category totals and a proportional native ring chart.
- **Undo:** the header’s curved arrow restores the previous ledger, including deletion,
  payment recording or resetting. One undo level is retained during the current run.
- **Trip options:** export a CSV or restore the original example after confirmation.
- Every change is validated and atomically saved. Invalid custom totals, zero/negative
  expenses, absent participants and malformed amounts are rejected without dismissal.

### Sample content

The September 6–10 Lisbon trip includes Alex, Jamie, Sam and You:
Alfama apartment (€640.00), Dinner at Prado (€168.50), Tram 28 day passes (€28.00),
Pastéis & coffee (€24.50), and Sunset on the Tagus (€120.00). Total: €981.00.
All four initially participate. Initial net balances are Alex +€43.24, Jamie −€217.26,
Sam −€220.74, You +€394.76.

### Persistence and exports

The sandbox Documents directory contains:

- `fairshare-trip.json`: versioned ledger, including expenses and recorded payments.
- `Fairshare-Lisbon.csv`: actual export created by Trip options or Insights. The native
  share sheet can save/send it. Documents are exposed in Files under Fairshare.

On Simulator, find the directory with:

```sh
xcrun simctl get_app_container <device-UUID> com.nativecollection.fairshare data
# append /Documents to the returned path
```

A corrupt saved ledger is not silently replaced. The UI reports the load failure and
blocks writes until the user confirms restoring the example. Recovery preserves a copy
of the original JSON beside the new file. Undo history itself is intentionally not
persisted; the resulting ledger is.

## Arithmetic and modeling

Money is stored as `Int` minor units; no floating-point arithmetic enters allocation,
net balances, payments or persistence. Amount entry accepts decimal dot or comma and
at most two fractional digits, up to €999,999.99 per expense. There are no currency
conversions, percentages, interest, taxes, receipt OCR or external payment integrations.

Equal splits assign `total / participantCount` cents to everyone, then distribute the
remainder in stable traveler-ID order. This is deterministic even if participant input
order changes. Repeated odd-cent expenses can leave travelers one or two cents apart.
Custom splits allow zero shares but must exactly total the expense.

Balances credit payers and debit allocated shares. Recorded payments credit their sender
and debit their recipient, preserving a zero-sum net balance. Changes to expenses after
a payment keep the historical payment intact and may create a new balance.

The settlement algorithm greedily matches the largest outstanding debtor and creditor.
It clears all balances in at most `nonzeroTravelers - 1` transfers, deterministically.
It is a simplified plan, **not a claim of globally minimal transfer count** for arbitrary
groups. The V1 trip has a fixed roster of four and a single currency.

CSV cells are quoted and formula-like text prefixes are escaped for spreadsheet safety.
Dates remain in the JSON ledger; CSV focuses on expense amounts, payers, allocations,
categories and payments.

## Verification

`scripts/check.sh` runs Xcode’s built-in `swift-format lint --strict`, validates both
property-list files, and runs the Foundation-only Swift package XCTest suite.
`scripts/build.sh` compiles/typechecks the real native UI for iOS Simulator.

To format after edits:

```sh
xcrun swift-format format --in-place --recursive App Core Tests Package.swift
```

Logic tests cover minor-unit parsing, order-independent rounding, traveler exclusion,
payer edits, custom allocation validation, known example balances, settlement conservation,
overpayments/duplicate payment rejection, 1,716 amount/participant combinations, JSON
round-trip and corrupt-file detection, invalid travelers and safe CSV quoting.

### Native UI demo

1. Inspect the illustrated first-launch trip.
2. Add “Riverside lunch” for €83.21, paid by You, excluding Sam.
3. Reopen it and change payer to Jamie; inspect the recalculated balances.
4. Try an invalid custom split; confirm rejection, correct it and save.
5. Record one suggested payment; confirm the updated plan and payment history.
6. Delete an expense and undo it.
7. Export the real CSV.
8. Terminate/relaunch and confirm the expense, payer, shares and payment persist.

The annotated native Simulator recording and final screenshots are session attachments,
not tracked source files.
