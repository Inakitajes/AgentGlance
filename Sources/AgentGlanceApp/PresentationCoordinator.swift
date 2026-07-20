import AppKit

import AgentGlanceCore

/// Chooses which surface hosts the session UI: the notch panel where the
/// target screen has a hardware notch, or the real macOS status item
/// everywhere else. Reacts to the same signals `NotchPanelController`
/// already listens for — a display change or the user picking a different
/// screen in Settings — so the two stay in lockstep as the target changes.
@MainActor
final class PresentationCoordinator {
    private let panelController: NotchPanelController
    private let setShowStatusItem: (Bool) -> Void
    private var screenObserver: NSObjectProtocol?
    private var displayPreferenceObserver: NSObjectProtocol?

    init(store: StateStore, setShowStatusItem: @escaping (Bool) -> Void) {
        panelController = NotchPanelController(store: store)
        self.setShowStatusItem = setShowStatusItem
        applyPresentation()
        screenObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.applyPresentation() }
        }
        displayPreferenceObserver = NotificationCenter.default.addObserver(
            forName: .agentGlanceDisplayPreferenceChanged,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.applyPresentation() }
        }
    }

    deinit {
        if let screenObserver {
            NotificationCenter.default.removeObserver(screenObserver)
        }
        if let displayPreferenceObserver {
            NotificationCenter.default.removeObserver(displayPreferenceObserver)
        }
    }

    private func applyPresentation() {
        let screen = PreferredScreen.resolve() ?? NSScreen.screens.first
        let hasNotch = (screen?.safeAreaInsets.top ?? 0) > 0
        if hasNotch {
            setShowStatusItem(false)
            panelController.show()
        } else {
            panelController.hide()
            setShowStatusItem(true)
        }
    }
}
