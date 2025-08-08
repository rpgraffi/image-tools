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
        let origPixel = asset.originalPixelSize
        let targetPixel = preview.targetPixelSize
        let sizeBytesBefore = asset.originalFileSizeBytes
        let sizeBytesAfter = preview.estimatedOutputBytes
        let beforeFmt = ImageExporter.inferFormat(from: asset.originalURL)
        let afterFmt = vm.selectedFormat ?? beforeFmt

        // Changes detection
        let resolutionChanged: Bool = {
            guard let o = origPixel, let t = targetPixel else { return false }
            return Int(o.width) != Int(t.width) || Int(o.height) != Int(t.height)
        }()
        let fileSizeChanged: Bool = {
            guard let b = sizeBytesBefore, let a = sizeBytesAfter else { return false }
            return b != a
        }()
        let formatChanged: Bool = (beforeFmt != afterFmt)

        ZStack(alignment: .topLeading) {
            // Image tile
            Group {
                if let t = asset.thumbnail {
                    Image(nsImage: t)
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: .infinity)
                        .aspectRatio(1, contentMode: .fit)
                        .compositingGroup()
                        .mask(RoundedRectangle(cornerRadius: 10, style: .continuous))
                } else {
                    Rectangle()
                        .fill(Color.gray.opacity(0.15))
                        .frame(maxWidth: .infinity)
                        .aspectRatio(1, contentMode: .fit)
                        .mask(RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
            }

            // Info overlay (only show lines that changed)
            VStack(alignment: .leading, spacing: 4) {
                if resolutionChanged, let o = origPixel, let t = targetPixel {
                    Text("Resolution: \(Int(o.width))×\(Int(o.height)) → \(Int(t.width))×\(Int(t.height))")
                }
                if fileSizeChanged, let b = sizeBytesBefore, let a = sizeBytesAfter {
                    Text("Size: \(formatBytes(b)) → \(formatBytes(a))")
                }
                if formatChanged, let bf = beforeFmt, let af = afterFmt {
                    Text("Format: \(bf.displayName) → \(af.displayName)")
                }
            }
            .font(.caption2)
            .foregroundStyle(.white)
            .padding(6)
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(Color.black.opacity(0.55))
            )
            .padding(6)
            .opacity((resolutionChanged || fileSizeChanged || formatChanged) ? 1 : 0)

            // Hover controls (top-right)
            HStack(spacing: 10) {
                Button(action: revealInFinder) { Image(systemName: "folder") }
                    .buttonStyle(.plain)
                    .help("Reveal in Finder")
                Button(action: copyToClipboard) { Image(systemName: "doc.on.doc") }
                    .buttonStyle(.plain)
                    .symbolEffect(.bounce.down.byLayer, options: .nonRepeating)
                    .help("Copy image to clipboard")
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
            .font(.system(size: 13))
            .foregroundStyle(.secondary)
            .padding(6)
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(Color.white.opacity(0.85))
            )
            .padding(6)
            .frame(maxWidth: .infinity, alignment: .topTrailing)
            .opacity(isHovering ? 1 : 0)

            // Edited badge
            if isEdited {
                Text("Edited")
                    .font(.caption2)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(
                        Capsule(style: .continuous).fill(Color.black.opacity(0.6))
                    )
                    .padding(8)
                    .frame(maxWidth: .infinity, alignment: .bottomLeading)
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
