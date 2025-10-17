import SwiftUI
import AppKit

// MARK: - Image Thumbnail
struct ImageThumbnail: View {
    let thumbnail: NSImage
    
    var body: some View {
        Image(nsImage: thumbnail)
            .resizable()
            .scaledToFit()
            .mask(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}

// MARK: - Info Overlay
struct InfoOverlay: View {
    let changeInfo: ImageChangeInfo
    
    var body: some View {
        HStack(alignment: .bottom, spacing: 6) {
            formatBadge
            resolutionBadge
            fileSizeBadge
        }
        .padding(6)
        .opacity(changeInfo.hasChanges ? 1 : 0)
    }
    
    @ViewBuilder
    private var formatBadge: some View {
        if changeInfo.formatChanged,
           let original = changeInfo.originalFormat,
           let target = changeInfo.targetFormat {
            TwoLineOverlayBadge(
                topText: original.displayName,
                bottomText: target.displayName
            )
        }
    }
    
    @ViewBuilder
    private var resolutionBadge: some View {
        if changeInfo.resolutionChanged,
           let original = changeInfo.originalPixelSize,
           let target = changeInfo.targetPixelSize {
            TwoLineOverlayBadge(
                topText: formatResolution(original),
                bottomText: formatResolution(target, padTo: original)
            )
        }
    }
    
    @ViewBuilder
    private var fileSizeBadge: some View {
        if let originalSize = changeInfo.originalFileSize {
            TwoLineOverlayBadge(
                topText: formatBytes(originalSize),
                bottomText: changeInfo.estimatedOutputSize.map { formatBytes($0) } ?? "--- KB",
                alignment: .trailing
            )
        }
    }
    
    private func formatResolution(_ size: CGSize, padTo reference: CGSize? = nil) -> String {
        let width = Int(size.width)
        let height = Int(size.height)
        
        guard let ref = reference else {
            return "\(width)×\(height)"
        }
        
        let refWidth = String(Int(ref.width))
        let refHeight = String(Int(ref.height))
        let widthStr = String(width)
        let heightStr = String(height)
        
        let padW = max(0, refWidth.count - widthStr.count)
        let padH = max(0, refHeight.count - heightStr.count)
        
        let paddedW = String(repeating: " ", count: padW) + widthStr
        let paddedH = String(repeating: " ", count: padH) + heightStr
        
        return "\(paddedW)×\(paddedH)"
    }
}

// MARK: - Hover Controls
struct HoverControls: View {
    let asset: ImageAsset
    let vm: ImageToolsViewModel
    let isVisible: Bool
    
    @State private var copyState: CopyState = .idle
    private let cornerRadius: CGFloat = 6
    
    private enum CopyState {
        case idle, success
    }
    
    var body: some View {
        HStack(spacing: 10) {
            revealButton
            copyButton
            removeButton
        }
        .font(.system(size: 13))
        .foregroundStyle(.secondary)
        .padding(6)
        .background(OverlayBackground(cornerRadius: cornerRadius))
        .padding(6)
        .frame(maxWidth: .infinity, alignment: .bottomTrailing)
        .opacity(isVisible ? 1 : 0)
    }
    
    private var revealButton: some View {
        Button(action: { ClipboardService.revealInFinder(asset.workingURL) }) {
            Image(systemName: "folder.fill")
        }
        .buttonStyle(.plain)
        .help(String(localized: "Reveal in Finder"))
    }
    
    private var copyButton: some View {
        Button(action: copyImageAction) {
            Image(systemName: copyState == .success ? "checkmark.app.fill" : "doc.on.doc.fill")
                .frame(width: 13, height: 13)
                .contentTransition(.symbolEffect(.replace))
        }
        .buttonStyle(.plain)
        .help(String(localized: "Copy image to clipboard"))
    }
    
    private var removeButton: some View {
        Button(role: .destructive, action: { vm.remove(asset) }) {
            Image(systemName: "xmark.circle.fill")
        }
        .buttonStyle(.plain)
        .help(String(localized: "Remove from list"))
    }
    
    private func copyImageAction() {
        Task {
            do {
                let pipeline = vm.buildPipeline()
                let encoded = try pipeline.renderEncodedData(on: asset)
                ClipboardService.copyEncodedImage(data: encoded.data, uti: encoded.uti)
            } catch {
                ClipboardService.copyImage(from: asset.workingURL)
            }
            
            copyState = .success
            try? await Task.sleep(for: .seconds(1))
            copyState = .idle
        }
    }
}

