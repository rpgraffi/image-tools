import SwiftUI
import AppKit

struct ImageRow: View {
    let asset: ImageAsset
    let isEdited: Bool
    @ObservedObject var vm: ImageToolsViewModel
    let toggle: () -> Void
    let recover: (() -> Void)?
    @State private var isHovering: Bool = false

    var body: some View {
        let preview = vm.previewInfo(for: asset)
        HStack(spacing: 16) {
            if let t = asset.thumbnail {
                Image(nsImage: t)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 64, height: 64)
                    .compositingGroup()
                    .mask(RoundedRectangle(cornerRadius: 8, style: .continuous))
            } else {
                Rectangle()
                    .fill(Color.gray.opacity(0.2))
                    .frame(width: 64, height: 64)
                    .mask(RoundedRectangle(cornerRadius: 8, style: .continuous))
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(asset.workingURL.lastPathComponent).font(.title3)
                HStack(spacing: 8) {
                    if let original = asset.originalPixelSize {
                        Text("orig: \(Int(original.width))×\(Int(original.height))")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    if let target = preview.targetPixelSize {
                        Text("→ \(Int(target.width))×\(Int(target.height))")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    if let bytes = preview.estimatedOutputBytes {
                        Text("≈ \(formatBytes(bytes))")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            Spacer()
            if isEdited {
                Text("Edited")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            HStack(spacing: 12) {
                Button(action: revealInFinder) { Image(systemName: "folder") }
                    .buttonStyle(.plain)
                    .help("Reveal in Finder")
                Button(action: copyToClipboard) { Image(systemName: "doc.on.doc") }
                    .buttonStyle(.plain)
                    .symbolEffect(.bounce.down.byLayer, options: .nonRepeating)
                    .help("Copy image to clipboard")
            }
            .opacity(isHovering ? 1 : 0)
            .font(.system(size: 14))
            .foregroundStyle(.secondary)
            Toggle(isOn: .constant(asset.isEnabled)) { EmptyView() }
                .toggleStyle(.checkbox)
                .onChange(of: asset.isEnabled) { _, _ in toggle() }
                .help("Enable/Disable for batch")
            if let recover {
                Button(action: recover) { Image(systemName: "clock.arrow.circlepath") }
                    .buttonStyle(.plain)
                    .help("Recover original")
            }
        }
        .contentShape(Rectangle())
        .onHover { isHovering = $0 }
        .animation(.easeInOut(duration: 0.15), value: isHovering)
    }

    private func copyToClipboard() {
        let pb = NSPasteboard.general
        pb.clearContents()
        var objects: [NSPasteboardWriting] = []
        if let image = NSImage(contentsOf: asset.workingURL) {
            objects.append(image)
        }
        objects.append(asset.workingURL as NSURL)
        pb.writeObjects(objects)
    }

    private func revealInFinder() {
        NSWorkspace.shared.activateFileViewerSelecting([asset.workingURL])
    }

    private func formatBytes(_ bytes: Int) -> String {
        let kb = 1024.0
        let mb = kb * 1024.0
        let b = Double(bytes)
        if b >= mb { return String(format: "%.2f MB", b/mb) }
        if b >= kb { return String(format: "%.0f KB", b/kb) }
        return "\(bytes) B"
    }
} 
