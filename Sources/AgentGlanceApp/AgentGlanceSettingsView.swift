import AppKit
import ServiceManagement
import SwiftUI

import AgentGlanceCore

struct AgentGlanceSettingsView: View {
    let store: StateStore?
    @AppStorage("hideWhenEmpty") private var hideWhenEmpty = false
    @AppStorage("attentionSoundEnabled") private var attentionSoundEnabled = true
    @AppStorage("turnCompleteSoundEnabled") private var turnCompleteSoundEnabled = true
    @AppStorage("preferredDisplayID") private var preferredDisplayID = -1
    @AppStorage("preferredDisplayName") private var preferredDisplayName = ""
    @State private var loginItemEnabled = SMAppService.mainApp.status == .enabled
    @State private var errorMessage: String?
    // Captured once per Settings appearance rather than re-read live: this
    // window is opened on demand, so a stale list only matters if a monitor
    // is plugged or unplugged with Settings already open.
    private let availableScreens = NSScreen.screens

    var body: some View {
        Form {
            Section {
                Toggle("Launch AgentGlance at login", isOn: Binding(
                    get: { loginItemEnabled },
                    set: updateLoginItem
                ))
                Toggle("Hide when no sessions are active", isOn: $hideWhenEmpty)
                Toggle("Play the alert sound when a session needs you", isOn: $attentionSoundEnabled)
                Toggle("Play a soft sound when a session finishes its turn", isOn: $turnCompleteSoundEnabled)
            }
            if availableScreens.count > 1 {
                Section {
                    Picker("Show the notch on", selection: $preferredDisplayID) {
                        Text("Automatic").tag(-1)
                        ForEach(availableScreens, id: \.self) { screen in
                            Text(screen.localizedName).tag(DisplayIdentity.id(for: screen))
                        }
                    }
                    .onChange(of: preferredDisplayID) {
                        preferredDisplayName = availableScreens
                            .first { DisplayIdentity.id(for: $0) == preferredDisplayID }?
                            .localizedName ?? ""
                        NotificationCenter.default.post(name: .agentGlanceDisplayPreferenceChanged, object: nil)
                    }
                } footer: {
                    Text("Falls back to the built-in display automatically if the chosen screen is disconnected.")
                }
            }
            Section {
                Button("Reset custom session names") {
                    store?.clearAllSessionNames()
                }
                .disabled(store == nil)
            } footer: {
                Text("Sessions renamed from the notch menu go back to their live tab titles.")
            }
            Section {
                LabeledContent("Version", value: Self.versionText)
                Button("Quit AgentGlance") {
                    NSApp.terminate(nil)
                }
            }
            if let errorMessage {
                Text(errorMessage)
                    .foregroundStyle(.red)
            }
        }
        .formStyle(.grouped)
        .padding()
        .frame(width: 390)
    }

    /// `swift run` executes outside the app bundle, where no Info.plist
    /// version exists — label those builds instead of hiding the row.
    private static var versionText: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "development"
    }

    private func updateLoginItem(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
            loginItemEnabled = enabled
            errorMessage = nil
        } catch {
            loginItemEnabled = SMAppService.mainApp.status == .enabled
            errorMessage = "Could not update the login item."
        }
    }
}
