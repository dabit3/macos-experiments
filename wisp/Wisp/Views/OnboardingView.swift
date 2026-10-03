import SwiftUI

struct OnboardingView: View {
    @Environment(AppState.self) private var app
    @State private var pastedKey = false
    @State private var key = ""
    @State private var reveal = false
    @State private var busy = false
    @State private var error: String?
    @FocusState private var focused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Spacer(minLength: 0)

            WispMark(size: 56)
                .padding(.bottom, 28)

            Text("Wisp")
                .font(.system(size: 44, weight: .semibold, design: .default))
                .tracking(-1)
            Text("A chat client for Abliteration AI.\nNothing is remembered unless you ask.")
                .font(.system(.body, design: .monospaced))
                .foregroundStyle(Color.ink.opacity(0.6))
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 8)

            Spacer(minLength: 32)

            VStack(alignment: .leading, spacing: 10) {
                Text("API KEY")
                    .font(.monoCaption)
                    .foregroundStyle(Color.ink.opacity(0.5))

                HStack(spacing: 8) {
                    Group {
                        if reveal {
                            TextField("abl_…", text: $key)
                        } else {
                            SecureField("abl_…", text: $key)
                        }
                    }
                    .font(.system(.body, design: .monospaced))
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .focused($focused)
                    .submitLabel(.go)
                    .onSubmit(connect)
                    .accessibilityIdentifier("apiKeyField")

                    Button {
                        reveal.toggle()
                    } label: {
                        Image(systemName: reveal ? "eye.slash" : "eye")
                    }
                    .accessibilityLabel(reveal ? "Hide key" : "Show key")

                    Button {
                        if let s = UIPasteboard.general.string {
                            key = s.trimmingCharacters(in: .whitespacesAndNewlines)
                            pastedKey = true
                        }
                    } label: {
                        Image(systemName: "doc.on.clipboard")
                    }
                    .accessibilityLabel("Paste key")
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .hairline(opacity: focused ? 1 : 0.35)
                .animation(.easeOut(duration: 0.15), value: focused)

                if let error {
                    Text(error)
                        .font(.mono)
                        .foregroundStyle(Color.ink)
                        .padding(.top, 2)
                        .transition(.opacity)
                }

                Text("Stored in the iOS Keychain on this device only. Get one at console.abliteration.ai.")
                    .font(.monoCaption)
                    .foregroundStyle(Color.ink.opacity(0.45))
                    .fixedSize(horizontal: false, vertical: true)
            }

            Button(action: connect) {
                if busy {
                    ProgressView().tint(.paper)
                } else {
                    Text("Connect")
                }
            }
            .buttonStyle(InkButtonStyle())
            .disabled(busy || key.trimmingCharacters(in: .whitespaces).isEmpty)
            .opacity(key.trimmingCharacters(in: .whitespaces).isEmpty ? 0.4 : 1)
            .padding(.top, 20)
            .accessibilityIdentifier("connectButton")
        }
        .padding(28)
        .background(Color.paper)
        .foregroundStyle(Color.ink)
        .onAppear { focused = true }
    }

    private func connect() {
        guard !busy else { return }
        busy = true
        error = nil
        Task {
            do {
                try await app.connect(apiKey: key)
                // Don't leave a live API key sitting on the system clipboard.
                if pastedKey { UIPasteboard.general.items = [] }
            } catch {
                withAnimation { self.error = error.localizedDescription }
            }
            busy = false
        }
    }
}

/// The open-ring mark used for the icon and onboarding.
struct WispMark: View {
    var size: CGFloat
    var body: some View {
        Circle()
            .trim(from: 0.12, to: 1.0)
            .stroke(
                AngularGradient(colors: [Color.ink.opacity(0), Color.ink], center: .center, startAngle: .degrees(0), endAngle: .degrees(360)),
                style: StrokeStyle(lineWidth: size * 0.11, lineCap: .round)
            )
            .rotationEffect(.degrees(-45))
            .frame(width: size, height: size)
            .accessibilityHidden(true)
    }
}
