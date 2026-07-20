import Foundation

public struct NotchLayout: Equatable, Sendable {
    public let width: CGFloat
    public let height: CGFloat
    /// Panel height while the session menu hangs below the notch bar.
    public let expandedHeight: CGFloat
    public let originX: CGFloat
    public let originY: CGFloat
    /// Room reserved left of the notch for Pi, Codex, and OpenCode.
    public let leftContentWidth: CGFloat
    /// Room reserved right of the notch for Claude.
    public let rightContentWidth: CGFloat
    /// The gap between wings: the real hardware notch's width.
    public let notchWidth: CGFloat

    public static let menuMaxHeight: CGFloat = 360

    /// The expanded silhouette casts a blurred drop shadow (radius 18, y: 8)
    /// that needs room to fade before hitting the window's edge — without
    /// it, a panel at maximum wing width on both sides leaves zero margin
    /// and the shadow gets hard-clipped into a floating rectangle instead of
    /// fading out. Reserved on every side (and doubled into width) so the
    /// panel's own center — and therefore the visible silhouette's screen
    /// position — never shifts.
    private static let shadowMargin: CGFloat = 36

    public init(
        screenMinX: CGFloat,
        screenWidth: CGFloat,
        screenMaxY: CGFloat,
        safeAreaTop: CGFloat,
        leftNotchEdgeX: CGFloat?,
        rightNotchEdgeX: CGFloat?
    ) {
        leftContentWidth = Self.wingWidth(activeToolCount: 3)
        rightContentWidth = Self.wingWidth(activeToolCount: 1)
        height = safeAreaTop > 0 ? safeAreaTop : 36
        expandedHeight = height + Self.menuMaxHeight + Self.shadowMargin
        let centerX = screenMinX + screenWidth / 2
        let leftEdge = leftNotchEdgeX ?? (centerX - 84)
        let rightEdge = rightNotchEdgeX ?? (centerX + 84)
        notchWidth = max(rightEdge - leftEdge, 168)
        width = leftContentWidth + notchWidth + rightContentWidth + 2 * Self.shadowMargin
        originX = leftEdge - leftContentWidth - Self.shadowMargin
        originY = screenMaxY - height
    }

    public static func wingWidth(activeToolCount: Int) -> CGFloat {
        let count = min(max(activeToolCount, 0), AgentTool.allCases.count)
        guard count > 0 else { return 30 }
        return CGFloat(count * 50 + (count - 1) * 6 + 20)
    }
}
