import AppKit

import AgentGlanceCore

/// Resolves which screen the user chose in Settings to host the notch (or
/// status item) on, shared by every presentation path so display-preference
/// lookup logic lives in exactly one place.
enum PreferredScreen {
    /// `nil` means no display was chosen in Settings — callers then keep
    /// their own default of whichever screen has keyboard focus.
    static func resolve() -> NSScreen? {
        let preferredID = UserDefaults.standard.integer(forKey: "preferredDisplayID")
        guard preferredID != -1 else { return nil }
        let preferredName = UserDefaults.standard.string(forKey: "preferredDisplayName") ?? ""
        let screens = NSScreen.screens
        let connected = screens.map { DisplayDescriptor(id: DisplayIdentity.id(for: $0), name: $0.localizedName) }
        guard let resolved = DisplayPreference.resolve(
            preferred: DisplayDescriptor(id: preferredID, name: preferredName),
            connected: connected
        ) else { return nil }
        return screens.first { DisplayIdentity.id(for: $0) == resolved.id }
    }
}
