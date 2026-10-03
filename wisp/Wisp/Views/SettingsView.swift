import SwiftUI

struct SettingsView: View {
    @Environment(AppState.self) private var app
    @Environment(\.dismiss) private var dismiss
    @State private var confirmForget = false

    var body: some View {
        @Bindable var app = app
        NavigationStack {
            Form {
                Section {
                    Toggle("Keep new chats by default", isOn: $app.settings.keepChatsByDefault)
                        .accessibilityIdentifier("keepByDefaultToggle")
                    Picker("Burn after leaving", selection: $app.settings.burnAfterLeaving) {
                        ForEach(BurnDelay.allCases) { d in
                            Text(d.label).tag(d)
                        }
                    }
                    .accessibilityIdentifier("burnDelayPicker")
                } header: {
                    header("MEMORY")
                } footer: {
                    Text("Off means every new chat is ephemeral until you bookmark it. Unkept chats burn this long after Wisp leaves the screen. Kept chats are stored only on this device.")
                        .font(.monoCaption)
                }
                .listRowBackground(rowBackground)

                Section {
                    Picker("Default model", selection: $app.settings.defaultModelID) {
                        ForEach(app.models) { m in
                            Text(m.displayName).tag(m.id)
                        }
                    }
                    .onChange(of: app.settings.defaultModelID) { _, new in
                        if app.current.isEmpty { app.current.modelID = new }
                    }
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text("Temperature")
                            Spacer()
                            Text(app.settings.temperature.formatted(.number.precision(.fractionLength(1))))
                                .font(.mono)
                                .foregroundStyle(Color.ink.opacity(0.6))
                        }
                        Slider(value: $app.settings.temperature, in: 0...2, step: 0.1)
                            .tint(.ink)
                    }
                    Toggle("Show reasoning", isOn: $app.settings.showReasoning)
                    Toggle("Show token cost", isOn: $app.settings.showCost)
                } header: {
                    header("MODEL")
                }
                .listRowBackground(rowBackground)

                Section {
                    TextField("You are…", text: $app.settings.systemPrompt, axis: .vertical)
                        .lineLimit(3...10)
                        .font(.system(.footnote, design: .monospaced))
                        .onChange(of: app.settings.systemPrompt) { _, new in
                            if app.current.isEmpty { app.current.systemPrompt = new }
                        }
                } header: {
                    header("SYSTEM PROMPT")
                } footer: {
                    Text("Applies to new chats. Leave empty for the raw model.")
                        .font(.monoCaption)
                }
                .listRowBackground(rowBackground)

                Section {
                    Picker("Appearance", selection: $app.settings.appearance) {
                        ForEach(Appearance.allCases) { a in
                            Text(a.rawValue.capitalized).tag(a)
                        }
                    }
                    .pickerStyle(.segmented)
                } header: {
                    header("APPEARANCE")
                }
                .listRowBackground(rowBackground)

                Section {
                    LabeledContent("Endpoint") {
                        Text(AbliterationClient.baseURL.host() ?? "")
                            .font(.mono)
                    }
                    LabeledContent("Key") {
                        Text(maskedKey)
                            .font(.mono)
                    }
                    Button("Forget key") { confirmForget = true }
                        .foregroundStyle(Color.ink)
                        .accessibilityIdentifier("forgetKeyButton")
                } header: {
                    header("ACCOUNT")
                } footer: {
                    Text(app.keychainUnavailable
                         ? "Keychain unavailable in this build — the key is held in memory only and you'll re-enter it next launch."
                         : "Wisp talks directly to api.abliteration.ai. No proxy, no analytics, nothing in between.")
                        .font(.monoCaption)
                }
                .listRowBackground(rowBackground)
            }
            .scrollContentBackground(.hidden)
            .background(Color.paper)
            .foregroundStyle(Color.ink)
            .tint(.ink)
            .toggleStyle(InkToggleStyle())
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Color.paper, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .font(.mono.weight(.semibold))
                }
            }
            .alert("Forget the API key on this device?", isPresented: $confirmForget) {
                Button("Forget key") {
                    dismiss()
                    Task {
                        try? await Task.sleep(for: .milliseconds(400))
                        app.forgetKey()
                    }
                }
                Button("Cancel", role: .cancel) {}
            }
        }
        .presentationBackground(Color.paper)
    }

    private var rowBackground: some View {
        Color.paper.overlay(Color.ink.opacity(0.05))
    }

    private var maskedKey: String {
        guard let k = app.apiKey else { return "—" }
        guard k.count > 8 else { return "••••" }
        return "\(k.prefix(4))…\(k.suffix(4))"
    }

    private func header(_ s: String) -> some View {
        Text(s).font(.monoCaption).foregroundStyle(Color.ink.opacity(0.5))
    }
}
