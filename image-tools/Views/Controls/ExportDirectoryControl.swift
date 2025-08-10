import SwiftUI
import AppKit

struct ExportDirectoryPill: View {
    @Binding var directory: URL?

    var body: some View {
        let height: CGFloat = Theme.Metrics.controlHeight
        let corner = Theme.Metrics.pillCornerRadius(forHeight: height)
        let isOn = directory != nil
        HStack(spacing: 8) {
            Label(directoryLabel, systemImage: "folder.fill")
                .font(.headline)
                .foregroundStyle(isOn ? Color.white : .primary)
                .frame(height: height)
            if isOn {
                Button(action: { withAnimation(Theme.Animations.spring()) { directory = nil } }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.headline)
                        .foregroundStyle(Color.white.opacity(0.9))
                }
                .buttonStyle(.plain)
                .help("Clear export folder")
            }
        }
        .padding(.horizontal, 12)
        .contentShape(Rectangle())
        .onTapGesture { pickDirectory() }
        .background(
            RoundedRectangle(cornerRadius: corner, style: .continuous)
                .fill(isOn ? Color.accentColor : Theme.Colors.controlBackground)
        )
        .clipShape(RoundedRectangle(cornerRadius: corner, style: .continuous))
        .animation(Theme.Animations.pillFill(), value: isOn)
        .help(isOn ? directory?.path ?? "" : "Choose export folder")
    }

    private var directoryLabel: String {
        if let dir = directory { return dir.lastPathComponent }
        return "Origin"
    }

    private func pickDirectory() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.prompt = "Choose"
        if panel.runModal() == .OK {
            directory = panel.urls.first
        }
    }
} 