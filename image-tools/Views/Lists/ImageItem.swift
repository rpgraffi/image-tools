import SwiftUI
import AppKit

// MARK: - Change Detection
struct ImageChangeInfo {
    let resolutionChanged: Bool
    let fileSizeChanged: Bool
    let formatChanged: Bool
    let originalPixelSize: CGSize?
    let targetPixelSize: CGSize?
    let originalFileSize: Int?
    let estimatedOutputSize: Int?
    let originalFormat: ImageFormat?
    let targetFormat: ImageFormat?
    
    var hasChanges: Bool {
        resolutionChanged || fileSizeChanged || formatChanged
    }
    
    init(asset: ImageAsset, vm: ImageToolsViewModel) {
        let preview = vm.previewInfo(for: asset)
        let origPixel = asset.originalPixelSize
        let targetPixel = preview.targetPixelSize
        let sizeBytesBefore = asset.originalFileSizeBytes
        let sizeBytesAfter = preview.estimatedOutputBytes
        let beforeFmt = ImageExporter.inferFormat(from: asset.originalURL)
        let afterFmt = vm.selectedFormat ?? beforeFmt
        
        self.originalPixelSize = origPixel
        self.targetPixelSize = targetPixel
        self.originalFileSize = sizeBytesBefore
        self.estimatedOutputSize = sizeBytesAfter
        self.originalFormat = beforeFmt
        self.targetFormat = afterFmt
        
        self.resolutionChanged = {
            guard let o = origPixel, let t = targetPixel else { return false }
            return Int(o.width) != Int(t.width) || Int(o.height) != Int(t.height)
        }()
        
        self.fileSizeChanged = {
            guard let b = sizeBytesBefore, let a = sizeBytesAfter else { return false }
            return b != a
        }()
        
        self.formatChanged = (beforeFmt != afterFmt)
    }
}

// MARK: - Subviews
private struct ImageThumbnail: View {
    let thumbnail: NSImage?
    
    var body: some View {
        Group {
            if let thumbnail = thumbnail {
                Image(nsImage: thumbnail)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: .infinity)
                    .aspectRatio(1, contentMode: .fill)
                    .compositingGroup()
                    .mask(RoundedRectangle(cornerRadius: 10, style: .continuous))
            } else {
                Rectangle()
                    .fill(Color.gray.opacity(0.15))
                    .frame(maxWidth: .infinity)
                    .aspectRatio(1, contentMode: .fill)
                    .mask(RoundedRectangle(cornerRadius: 10, style: .continuous))
            }
        }
    }
}

// Reusable two-line overlay badge used by InfoOverlay
private struct TwoLineOverlayBadge: View {
    let topText: String
    let bottomText: String
    let animateFlag: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(topText).foregroundStyle(.secondary)
            Text(bottomText)
        }
        .font(.caption2)
        .foregroundStyle(.white)
        .monospaced(true)
        .padding(6)
        .background(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(Material.ultraThin)
        )
    }
}

private struct InfoOverlay: View {
    let changeInfo: ImageChangeInfo
    
    var body: some View {
        HStack(alignment: .bottom, spacing: 6) {
            
            // Format change overlay
            if changeInfo.formatChanged,
               let originalFormat = changeInfo.originalFormat,
               let targetFormat = changeInfo.targetFormat {
                TwoLineOverlayBadge(
                    topText: originalFormat.displayName,
                    bottomText: targetFormat.displayName,
                    animateFlag: changeInfo.formatChanged
                )
            }
            // Resolution change overlay
            if changeInfo.resolutionChanged,
               let original = changeInfo.originalPixelSize,
               let target = changeInfo.targetPixelSize {
                TwoLineOverlayBadge(
                    topText: "\(Int(original.width))×\(Int(original.height))",
                    bottomText: "\(Int(target.width))×\(Int(target.height))",
                    animateFlag: changeInfo.resolutionChanged
                )
            }
            
            // File size change overlay
            if changeInfo.fileSizeChanged,
               let originalSize = changeInfo.originalFileSize,
               let outputSize = changeInfo.estimatedOutputSize {
                TwoLineOverlayBadge(
                    topText: "\(formatBytes(originalSize))",
                    bottomText: "\(formatBytes(outputSize))",
                    animateFlag: changeInfo.fileSizeChanged
                )
            }
        }
        .padding(6)
        .opacity(changeInfo.hasChanges ? 1 : 0)
    }
}

private struct HoverControls: View {
    let asset: ImageAsset
    let vm: ImageToolsViewModel
    let toggle: () -> Void
    let recover: (() -> Void)?
    let isVisible: Bool
    
    @State private var animationTrigger: Int = 0
    
    var body: some View {
        HStack(spacing: 10) {
            Button(action: { revealInFinder(asset.workingURL) }) {
                Image(systemName: "folder.fill")
            }
            .buttonStyle(.plain)
            .help("Reveal in Finder")
            
            Button(action: {
                Task {
                    do {
                        let pipeline = vm.buildPipeline()
                        let tempURL = try pipeline.renderTemporaryURL(on: asset)
                        copyURLImageToClipboard(tempURL)
                        let tempRoot = FileManager.default.temporaryDirectory.standardizedFileURL.path
                        let isTemp = tempURL.standardizedFileURL.path.hasPrefix(tempRoot)
                        let isOriginal = tempURL.standardizedFileURL == asset.workingURL.standardizedFileURL
                        if isTemp && !isOriginal {
                            try? FileManager.default.removeItem(at: tempURL)
                        }
                    } catch {
                        copyURLImageToClipboard(asset.workingURL)
                    }
                    await MainActor.run { animationTrigger += 1 }
                }
            }) {
                Image(systemName: "doc.on.doc.fill")
            }
            .buttonStyle(.plain)
            .symbolEffect(.bounce.down.wholeSymbol, options: .nonRepeating, value: animationTrigger)
            .help("Copy image to clipboard")
            
            Toggle(isOn: .constant(asset.isEnabled)) {
                EmptyView()
            }
            .toggleStyle(.checkbox)
            .onChange(of: asset.isEnabled) { _, _ in toggle() }
            .help("Enable/Disable for batch")
            
            if let recover = recover {
                Button(action: recover) {
                    Image(systemName: "clock.arrow.circlepath")
                }
                .buttonStyle(.plain)
                .help("Recover original")
            }
            
            Button(role: .destructive, action: { vm.remove(asset) }) {
                Image(systemName: "trash")
            }
            .buttonStyle(.plain)
            .help("Remove from list")
        }
        .font(.system(size: 13))
        .foregroundStyle(.secondary)
        .padding(6)
        .background(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(Material.ultraThin)
        )
        .padding(6)
        .frame(maxWidth: .infinity, alignment: .bottomTrailing)
        .opacity(isVisible ? 1 : 0)
    }
}

private struct EditedBadge: View {
    let isEdited: Bool
    
    var body: some View {
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
}

// MARK: - Main View
struct ImageItem: View {
    let asset: ImageAsset
    @ObservedObject var vm: ImageToolsViewModel
    let toggle: () -> Void
    let recover: (() -> Void)?
    @State private var isHovering: Bool = false
    
    var body: some View {
        let changeInfo = ImageChangeInfo(asset: asset, vm: vm)
        
        ZStack {
            // Background thumbnail
            ImageThumbnail(thumbnail: asset.thumbnail)
            
            // Top right overlay
            ZStack(alignment: .topTrailing) {
                Color.clear
                
                HoverControls(
                    asset: asset,
                    vm: vm,
                    toggle: toggle,
                    recover: recover,
                    isVisible: isHovering
                )
            }
            
            // Bottom left overlay
            ZStack(alignment: .bottomLeading) {
                Color.clear
                
                VStack(alignment: .leading, spacing: 4) {
                    InfoOverlay(changeInfo: changeInfo)
                    EditedBadge(isEdited: asset.isEdited)
                }
            }
        }
        .contentShape(Rectangle())
        .onHover { isHovering = $0 }
        .animation(.easeInOut(duration: 0.15), value: isHovering)
    }
}

// MARK: - Helper Functions
private func copyToClipboard(_ asset: ImageAsset) {
    let pb = NSPasteboard.general
    pb.clearContents()
    var objects: [NSPasteboardWriting] = []
    if let image = NSImage(contentsOf: asset.workingURL) {
        objects.append(image)
    }
    objects.append(asset.workingURL as NSURL)
    pb.writeObjects(objects)
}

private func copyURLImageToClipboard(_ url: URL) {
    let pb = NSPasteboard.general
    pb.clearContents()
    if let image = NSImage(contentsOf: url) {
        pb.writeObjects([image])
    } else {
        pb.writeObjects([url as NSURL])
    }
}

private func revealInFinder(_ url: URL) {
    NSWorkspace.shared.activateFileViewerSelecting([url])
}

private func formatBytes(_ bytes: Int) -> String {
    let kb = 1024.0
    let mb = kb * 1024.0
    let b = Double(bytes)
    if b >= mb { return String(format: "%.2f MB", b/mb) }
    if b >= kb { return String(format: "%.0f KB", b/kb) }
    return "\(bytes) B"
}

// MARK: - Preview
#Preview("Image Item - New") {
    ImageItem(
        asset: PreviewData.newImageAsset,
        vm: PreviewData.mockViewModel,
        toggle: {},
        recover: nil
    )
    .frame(width: 200, height: 200)
    .padding()
}

#Preview("Image Item - Edited") {
    ImageItem(
        asset: PreviewData.editedImageAsset,
        vm: PreviewData.mockViewModel,
        toggle: {},
        recover: {}
    )
    .frame(width: 200, height: 200)
    .padding()
}

#Preview("Image Item - No Thumbnail") {
    ImageItem(
        asset: PreviewData.noThumbnailAsset,
        vm: PreviewData.mockViewModel,
        toggle: {},
        recover: nil
    )
    .frame(width: 200, height: 200)
    .padding()
}

// MARK: - Preview Data
private struct PreviewData {
    static let newImageAsset: ImageAsset = {
        var asset = ImageAsset(url: URL(fileURLWithPath: "/tmp/sample.jpg"))
        // Create a mock blue thumbnail
        let mockImage = NSImage(size: NSSize(width: 100, height: 100))
        mockImage.lockFocus()
        NSColor.systemBlue.setFill()
        NSRect(x: 0, y: 0, width: 100, height: 100).fill()
        mockImage.unlockFocus()
        asset.thumbnail = mockImage
        asset.originalPixelSize = CGSize(width: 1920, height: 1080)
        asset.originalFileSizeBytes = 2048576 // 2MB
        return asset
    }()
    
    static let editedImageAsset: ImageAsset = {
        var asset = ImageAsset(url: URL(fileURLWithPath: "/tmp/edited.jpg"))
        // Create a mock green thumbnail
        let mockImage = NSImage(size: NSSize(width: 100, height: 100))
        mockImage.lockFocus()
        NSColor.systemGreen.setFill()
        NSRect(x: 0, y: 0, width: 100, height: 100).fill()
        mockImage.unlockFocus()
        asset.thumbnail = mockImage
        asset.originalPixelSize = CGSize(width: 1920, height: 1080)
        asset.originalFileSizeBytes = 2048576 // 2MB
        asset.isEdited = true
        return asset
    }()
    
    static let noThumbnailAsset: ImageAsset = {
        var asset = ImageAsset(url: URL(fileURLWithPath: "/tmp/no-thumb.jpg"))
        asset.thumbnail = nil
        asset.originalPixelSize = CGSize(width: 800, height: 600)
        asset.originalFileSizeBytes = 512000 // 512KB
        return asset
    }()
    
    static let mockViewModel: ImageToolsViewModel = {
        return ImageToolsViewModel()
    }()
} 
