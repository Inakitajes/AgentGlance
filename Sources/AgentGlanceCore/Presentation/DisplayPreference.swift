import Foundation

/// A connected screen, identified well enough to survive a reconnect:
/// `CGDirectDisplayID` is the primary key, but it isn't guaranteed stable
/// across unplugging a monitor, so the name backs it up.
public struct DisplayDescriptor: Equatable, Sendable {
    public let id: Int
    public let name: String

    public init(id: Int, name: String) {
        self.id = id
        self.name = name
    }
}

public enum DisplayPreference {
    /// Resolves which connected screen the notch should render on.
    ///
    /// No saved preference means "use whatever today's default screen is" —
    /// the caller supplies that as `connected.first`. A saved preference is
    /// matched by id first, then by name for the case a reconnect changed
    /// the id, and otherwise falls back to the first connected screen so an
    /// unplugged display never leaves the notch homeless.
    public static func resolve(
        preferred: DisplayDescriptor?,
        connected: [DisplayDescriptor]
    ) -> DisplayDescriptor? {
        guard let preferred else { return connected.first }
        return connected.first { $0.id == preferred.id }
            ?? connected.first { $0.name == preferred.name }
            ?? connected.first
    }
}
