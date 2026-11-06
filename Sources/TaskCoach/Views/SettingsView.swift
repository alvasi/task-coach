import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var model: AppModel
    @State private var linearKey = ""
    @State private var pathText = ""
    @State private var confirmReset = false
    @State private var hasLinearKey = false
    @State private var showAdvanced = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                group("General") {
                    row("Menu bar icon") { toggle(\.showInMenuBar) }
                        // Never let both go: with neither, there'd be no way back into the app.
                        .disabled(!model.state.showInDock)
                    divider
                    row("Dock icon") { toggle(\.showInDock) }
                        .disabled(!model.state.showInMenuBar)
                    divider
                    row("Open at login") {
                        Toggle("", isOn: Binding(get: { model.opensAtLogin }, set: { model.setOpensAtLogin($0) }))
                            .labelsHidden().toggleStyle(.switch).controlSize(.small)
                    }
                    if model.loginNeedsApproval {
                        HStack {
                            Hint("macOS needs you to approve this once.")
                            Spacer()
                            Button("Open Login Items") { model.openLoginItemsSettings() }
                                .buttonStyle(SoftButtonStyle())
                        }
                    }
                    divider
                    row("Theme") {
                        Picker("", selection: binding(\.appearance)) {
                            Text("System").tag("system")
                            Text("Light").tag("light")
                            Text("Dark").tag("dark")
                        }
                        .pickerStyle(.segmented)
                        .labelsHidden()
                        .frame(width: 190)
                    }
                    if !(model.state.showInMenuBar && model.state.showInDock) {
                        Hint(model.state.showInDock
                             ? "Menu bar icon is off. Open Task Coach from the Dock or Applications."
                             : "Dock icon is off. Open the window from the menu bar icon.")
                    }
                }

                group("Quizzes") {
                    row("Offer a quiz when a Claude session finishes") { toggle(\.nudgeAfterSessions) }
                    divider
                    row("Daily pulse: one question") { toggle(\.dailyRecap) }
                    divider
                    row("Pulse time") { stepper("\(model.state.dailyHour):00", \.dailyHour, 8...22) }
                        .disabled(!model.state.dailyRecap)
                    divider
                    VStack(alignment: .leading, spacing: 4) {
                        Text("About your work (optional)").font(.serif(14))
                        TextField("e.g. a .NET backend and React web app for a messaging product",
                                  text: binding(\.workContext), axis: .vertical)
                            .textFieldStyle(.roundedBorder)
                            .lineLimit(2...4)
                        Hint("Helps questions use the right words for your product and stack. Stays on your Mac, sent only with quiz requests.")
                    }
                    divider
                    row("Questions per sitting") { stepper("\(model.state.questionsPerSitting)", \.questionsPerSitting, 1...5) }
                    Hint("At most one session nudge a day, plus the pulse. You can stop after any question.")
                }

                VStack(alignment: .leading, spacing: 0) {
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) { showAdvanced.toggle() }
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "chevron.right").font(.system(size: 9, weight: .bold))
                                .rotationEffect(.degrees(showAdvanced ? 90 : 0))
                            Text("Advanced").font(.serif(14, .bold))
                            Text("Claude model, Linear, look-back, reset").font(.serif(12.5)).italic().foregroundStyle(Theme.inkMuted)
                            Spacer()
                        }
                        .foregroundStyle(Theme.ink)
                        .padding(.vertical, 6)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)

                    if showAdvanced { advanced.padding(.top, 8) }
                }
                .padding(.horizontal, 4)

                HStack {
                    Spacer()
                    Button {
                        NSApp.terminate(nil)
                    } label: {
                        Label("Quit Task Coach", systemImage: "power")
                    }
                    .buttonStyle(SoftButtonStyle(tint: Theme.inkMuted))
                }
            }
            .padding(.horizontal, 14)
            .padding(.bottom, 14)
        }
        .onAppear {
            pathText = model.state.claudePathOverride ?? ""
            hasLinearKey = Keychain.read() != nil
        }
        .confirmationDialog("Reset all skill stats and the review queue?", isPresented: $confirmReset) {
            Button("Reset", role: .destructive) { model.resetProgress() }
        }
    }

    private func binding<T>(_ keyPath: WritableKeyPath<AppState, T>) -> Binding<T> {
        Binding(get: { model.state[keyPath: keyPath] },
                set: { model.state[keyPath: keyPath] = $0; model.persist() })
    }

    private var advanced: some View {
        VStack(alignment: .leading, spacing: 12) {
            group("Claude") {
                row("Model") {
                    Picker("", selection: binding(\.model)) {
                        Text("Sonnet · fast").tag("sonnet")
                        Text("Opus · deeper").tag("opus")
                        Text("Haiku · fastest").tag("haiku")
                    }
                    .labelsHidden()
                    .frame(width: 140)
                }
                divider
                HStack(spacing: 6) {
                    Circle().fill(model.claudePath == nil ? Theme.bad : Theme.good).frame(width: 7, height: 7)
                    Text(model.claudePath == nil ? "claude CLI not found" : "claude CLI found")
                        .font(.serif(13.5))
                    Spacer()
                }
                if let path = model.claudePath {
                    Text(path).font(.system(size: 10.5, design: .monospaced)).foregroundStyle(Theme.inkMuted)
                        .lineLimit(2).truncationMode(.middle).textSelection(.enabled)
                }
                HStack {
                    TextField("Custom path (optional)", text: $pathText).textFieldStyle(.roundedBorder)
                    Button("Save") {
                        model.state.claudePathOverride = pathText.isEmpty ? nil : pathText
                        model.persist()
                    }
                    .buttonStyle(SoftButtonStyle())
                }
                Hint("Login error? Open Terminal, run claude, then type /login.")
            }

            group("Linear") {
                Hint("Optional. Without a key, tickets come from your Claude sessions. With one, every assigned ticket shows up.")
                HStack {
                    SecureField(hasLinearKey ? "Key saved in Keychain" : "Personal API key", text: $linearKey)
                        .textFieldStyle(.roundedBorder)
                    Button(hasLinearKey && linearKey.isEmpty ? "Remove" : "Save") {
                        let key = linearKey
                        linearKey = ""
                        Task {
                            await model.saveLinearKey(key)
                            hasLinearKey = Keychain.read() != nil
                        }
                    }
                    .buttonStyle(SoftButtonStyle())
                }
                if let status = model.linearStatus { Hint(status) }
            }

            group("Playbook") {
                row("\(model.playbook.count) practices") {
                    HStack(spacing: 8) {
                        Button("Open") { NSWorkspace.shared.open(Playbook.userFile) }
                            .buttonStyle(SoftButtonStyle())
                        Button("Reload") { model.reloadPlaybook() }
                            .buttonStyle(SoftButtonStyle())
                    }
                }
                Hint("Every practice and transfer question must cite one of these. Edit the file, then Reload.")
            }

            group("Data") {
                row("Look back over Claude sessions from the last") {
                    stepper("\(model.state.lookbackDays) days", \.lookbackDays, 1...30)
                }
                divider
                row("Skill stats and review queue") {
                    Button("Reset…") { confirmReset = true }
                        .buttonStyle(SoftButtonStyle(tint: Theme.bad))
                }
            }
        }
    }

    private var divider: some View { Divider().opacity(0.5) }

    private func toggle(_ keyPath: WritableKeyPath<AppState, Bool>) -> some View {
        Toggle("", isOn: binding(keyPath)).labelsHidden().toggleStyle(.switch).controlSize(.small)
    }

    private func stepper(_ label: String, _ keyPath: WritableKeyPath<AppState, Int>, _ range: ClosedRange<Int>) -> some View {
        Stepper(label, value: binding(keyPath), in: range)
            .font(.serif(13.5))
    }

    private func row<Trailing: View>(_ title: String, @ViewBuilder trailing: () -> Trailing) -> some View {
        HStack {
            Text(title).font(.serif(14))
            Spacer()
            trailing()
        }
        .frame(minHeight: 26)
    }

    private func group<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionHeader(title: title).padding(.bottom, 2)
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .card()
    }
}

private struct Hint: View {
    let text: String
    init(_ text: String) { self.text = text }
    var body: some View {
        Text(text).font(.serif(13)).foregroundStyle(Theme.inkMuted).fixedSize(horizontal: false, vertical: true)
    }
}
