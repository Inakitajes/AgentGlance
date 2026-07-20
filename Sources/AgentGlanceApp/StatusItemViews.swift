import SwiftUI

import AgentGlanceCore

/// The `MenuBarExtra` label: a tiny aggregate glyph across every tool,
/// shown in the real system status bar on screens without a hardware
/// notch. Unlike the notch pill, this renders against whatever background
/// the system menu bar actually has, so colors stay adaptive.
struct StatusItemIconView: View {
    @Bindable var store: StateStore

    var body: some View {
        let summaries = ToolSummary.active(in: store.acknowledgments.silenced(store.sessions))
        let sessionCount = summaries.reduce(0) { $0 + $1.sessionCount }
        let needsAttention = summaries.contains { $0.needsAttention }
        let isWorking = summaries.contains { $0.worstStatus == .working }

        HStack(spacing: 4) {
            if needsAttention {
                Circle()
                    .fill(.red)
                    .frame(width: 7, height: 7)
            } else if isWorking {
                WorkingPixelSpinner(color: .primary)
            } else {
                Image(systemName: "moon.zzz.fill")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
            }
            if sessionCount > 0 {
                Text(sessionCount, format: .number)
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .monospacedDigit()
            }
        }
    }
}

/// The `MenuBarExtra` content window: every tool with active sessions,
/// stacked as the same `SessionMenuCard` the notch panel uses — the status
/// item is a different entry point onto identical session management, not
/// a parallel UI.
struct StatusItemMenuView: View {
    @Bindable var store: StateStore
    @Environment(\.openSettings) private var openSettings

    var body: some View {
        let summaries = ToolSummary.active(in: store.acknowledgments.silenced(store.sessions))
        VStack(spacing: 0) {
            if summaries.isEmpty {
                Text("No active sessions")
                    .font(.system(size: 12))
                    .foregroundStyle(.white.opacity(0.45))
                    .padding(16)
            } else {
                ForEach(summaries, id: \.tool) { summary in
                    SessionMenuCard(
                        tool: summary.tool,
                        sessions: store.sessions(for: summary.tool),
                        dismiss: {},
                        acknowledge: { store.acknowledge($0) },
                        sessionTitle: { store.displayName(for: $0) },
                        overrideName: { store.nameOverrides.displayName(for: $0) },
                        rename: { store.rename($0, to: $1) },
                        setKeyboardFocus: { _ in },
                        onRowInteractionChange: { _ in }
                    )
                }
            }
            Divider().overlay(.white.opacity(0.08))
            HStack {
                SettingsGearButton {
                    NSApp.activate(ignoringOtherApps: true)
                    openSettings()
                }
                Spacer()
                Button {
                    NSApp.terminate(nil)
                } label: {
                    Label("Quit AgentGlance", systemImage: "power")
                        .font(.system(size: 11))
                }
                .buttonStyle(.plain)
                .foregroundStyle(.white.opacity(0.55))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
        }
        .frame(width: 300)
        .background(.black)
    }
}
