import SwiftUI
import AppKit

struct ExportDirectoryPill: View {
    @Binding var directory: URL?

    var body: some View {
        let height: CGFloat = Theme.Metrics.controlHeight
        let corner = Theme.Metrics.pillCornerRadius(forHeight: height)
        let isOn = directory != nil
        HStack(spacing: 8) {
            if isOn {
                Label(directoryLabel, systemImage: "folder.fill")
                    .font(Theme.Fonts.button)
                    .foregroundStyle(Color.white)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .frame(height: height)
            } else {
                Image(systemName: "folder.fill")
                    .font(Theme.Fonts.button)
                    .foregroundStyle(.primary)
                    .frame(height: height)
            }
            if isOn {
                Button(action: { withAnimation(Theme.Animations.spring()) { directory = nil } }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(Theme.Fonts.button)
                        .foregroundStyle(.primary)
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
        .help(isOn ? (directory?.path ?? "") : String(localized: "Choose export folder"))
    }

    private var directoryLabel: String {
        if let dir = directory { return dir.lastPathComponent }
        return String(localized: "Origin")
    }

    private func pickDirectory() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.prompt = String(localized: "Choose")
        if panel.runModal() == .OK {
            directory = panel.urls.first
        }
    }
} 
