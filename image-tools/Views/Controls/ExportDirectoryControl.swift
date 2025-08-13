import SwiftUI
import AppKit

struct ExportDirectoryPill: View {
    @Binding var directory: URL?
    var sourceDirectory: URL?
    var hasActiveImages: Bool

    var body: some View {
        let height: CGFloat = Theme.Metrics.controlHeight
        let corner = Theme.Metrics.pillCornerRadius(forHeight: height)
        // Highlight only when user explicitly chose a destination dir
        let isOn = directory != nil
        HStack(spacing: 8) {
            if isOn {
                Label(currentLabel, systemImage: "folder.fill")
                    .font(Theme.Fonts.button)
                    .foregroundStyle(Color.white)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .frame(height: height)
            } else {
                Label(currentLabel, systemImage: "folder.fill")
                    .font(Theme.Fonts.button)
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .frame(height: height)
            }
            if isOn {
                Button(action: { withAnimation(Theme.Animations.spring()) { directory = nil } }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(Theme.Fonts.button)
                        .foregroundStyle(Color.white)
                }
                .buttonStyle(.plain)
                .help(String(localized: "Clear export folder"))
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
        .help(isOn ? (directory?.path ?? "") : (currentTooltip))
    }

    private var currentLabel: String {
        if let dir = directory { return dir.lastPathComponent }
        if hasActiveImages, let src = sourceDirectory { return src.lastPathComponent }
        return String(localized: "Destination")
    }

    private var currentTooltip: String {
        if let dir = directory { return dir.path }
        if let src = sourceDirectory { return src.path }
        return String(localized: "Choose export folder")
    }

    private func pickDirectory() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.canCreateDirectories = true
        panel.prompt = String(localized: "Choose")
        if panel.runModal() == .OK {
            directory = panel.urls.first
        }
    }
} 
