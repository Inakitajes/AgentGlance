import AppKit
import SwiftUI

import AgentGlanceCore

@main
struct AgentGlanceApplication: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        Settings {
            AgentGlanceSettingsView(store: appDelegate.store)
        }
        // Screens without a hardware notch host the session UI as a normal
        // status item instead of a floating panel; `PresentationCoordinator`
        // toggles this binding as the target screen changes.
        MenuBarExtra(
            isInserted: Binding(
                get: { appDelegate.showStatusItem },
                set: { appDelegate.showStatusItem = $0 }
            )
        ) {
            if let store = appDelegate.store {
                StatusItemMenuView(store: store)
            }
        } label: {
            if let store = appDelegate.store {
                StatusItemIconView(store: store)
            }
        }
        .menuBarExtraStyle(.window)
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, ObservableObject {
    private var presentationCoordinator: PresentationCoordinator?
    private(set) var store: StateStore?
    private var observationScheduler: ObservationScheduler?
    private var focusAcknowledgmentObserver: FocusAcknowledgmentObserver?
    @Published var showStatusItem = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        guard terminateBecauseAnotherInstanceRuns() == false else { return }
        // The notch silhouette is always solid black regardless of the
        // system's light/dark setting; every native surface the app owns —
        // the panel's right-click menu, the Settings window — must match
        // instead of following the system appearance on its own.
        NSApp.appearance = NSAppearance(named: .darkAqua)
        NSApp.setActivationPolicy(.accessory)
        let stateDirectory = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".agentglance/state", isDirectory: true)
        let repository = StateRepository(directoryURL: stateDirectory)
        // Session names live next to — never inside — the state directory:
        // the store watches that directory and decode-attempts every .json.
        let store = StateStore(
            repository: repository,
            nameOverridesFileURL: FileManager.default.homeDirectoryForCurrentUser
                .appendingPathComponent(".agentglance/session-names.json")
        )
        self.store = store
        // Two-sound language: the system alert (user-configured sound and
        // volume) means "a session needs you"; the soft Tink means "the
        // agent finished its turn — the conversation is yours".
        UserDefaults.standard.register(defaults: [
            "attentionSoundEnabled": true,
            "turnCompleteSoundEnabled": true,
            // -1 means "no display chosen" — currentLayout() falls back to
            // whichever screen has keyboard focus, today's original default.
            "preferredDisplayID": -1,
            "preferredDisplayName": "",
        ])
        store.onAttentionRaised = { _ in
            guard UserDefaults.standard.bool(forKey: "attentionSoundEnabled") else { return }
            NSSound.beep()
        }
        store.onTurnCompleted = { _ in
            guard UserDefaults.standard.bool(forKey: "turnCompleteSoundEnabled") else { return }
            NSSound(named: "Tink")?.play()
        }
        do {
            // Directory events and Darwin notifications deliver state changes
            // immediately; polling is only a 30-second safety heartbeat.
            try store.startObserving(pollInterval: 30)
        } catch {
            store.stopObserving()
            NSLog("AgentGlance failed to start state observation: %@", String(describing: error))
        }
        presentationCoordinator = PresentationCoordinator(store: store) { [weak self] shouldShow in
            self?.showStatusItem = shouldShow
        }
        let scheduler = ObservationScheduler(repository: repository)
        observationScheduler = scheduler
        scheduler.start()
        let focusObserver = FocusAcknowledgmentObserver(store: store)
        focusAcknowledgmentObserver = focusObserver
        focusObserver.start()
    }

    /// Two live instances fight over `~/.agentglance/state`: each reaper
    /// rewrites sessions with its own view of the process table and the
    /// write ping-pong storms both apps (observed 2026-07-18 at ~100% CPU).
    /// The newest instance defers to the one already running.
    private func terminateBecauseAnotherInstanceRuns() -> Bool {
        guard let bundleIdentifier = Bundle.main.bundleIdentifier else { return false }
        let others = NSRunningApplication
            .runningApplications(withBundleIdentifier: bundleIdentifier)
            .filter {
                $0.processIdentifier != ProcessInfo.processInfo.processIdentifier
                    && !$0.isTerminated // a just-killed instance can linger in the list
            }
        guard let existing = others.first else { return false }
        NSLog(
            "AgentGlance: another instance (pid %d) is already running; exiting.",
            existing.processIdentifier
        )
        NSApp.terminate(nil)
        return true
    }
}
