import SwiftUI
import AppKit
import UniformTypeIdentifiers

struct ExportDirectoryControl: View {
    @Binding var directory: URL?
    var sourceDirectory: URL?
    var hasActiveImages: Bool
    @State private var isDropping: Bool = false
    
    var body: some View {
        let height: CGFloat = Theme.Metrics.controlHeight
        let corner = Theme.Metrics.pillCornerRadius(forHeight: height)
        // Highlight only when user explicitly chose a destination dir
        let isOn = directory != nil
        HStack(spacing: 8) {
            Label(currentLabel, systemImage: "folder.fill")
                .font(Theme.Fonts.button)
                .foregroundStyle(isOn ? .white : .primary)
                .lineLimit(1)
                .frame(height: height)
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
        .overlay(
            RoundedRectangle(cornerRadius: corner, style: .continuous)
                .stroke(style: StrokeStyle(lineWidth: 2, dash: [6, 4]))
                .foregroundStyle(isDropping ? (isOn ? Color.white : Color.accentColor) : Color.clear)
        )
        .animation(Theme.Animations.pillFill(), value: isOn)
        .help(String(localized: "Choose export folder"))
        .dropDestination(for: URL.self) { items, _ in
            guard let folder = items.first else { return false }
            var isDirectory: ObjCBool = false
            guard FileManager.default.fileExists(atPath: folder.path, isDirectory: &isDirectory), isDirectory.boolValue else {
                return false
            }
            directory = folder.standardizedFileURL
            return true
        } isTargeted: { hovering in
            isDropping = hovering
            if hovering { Haptics.generic() } else { Haptics.alignment() }
        }
    }
    
    private var currentLabel: String {
        if let dir = directory { return dir.lastPathComponent }
        if hasActiveImages, let src = sourceDirectory { return src.lastPathComponent }
        return String(localized: "Destination")
    }
    
    private func pickDirectory() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.canCreateDirectories = true
        panel.prompt = String(localized: "Choose")
        if panel.runModal() == .OK {
            if let chosen = panel.urls.first?.standardizedFileURL {
                SandboxAccessManager.shared.register(url: chosen)
                directory = chosen
            }
        }
    }
    
}
