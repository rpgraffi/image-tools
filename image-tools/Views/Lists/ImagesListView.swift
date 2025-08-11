import SwiftUI
import UniformTypeIdentifiers
import AppKit

struct ImagesListView: View {
    @ObservedObject var vm: ImageToolsViewModel
    @Binding var isDropping: Bool
    let onPickFromFinder: () -> Void

    // Layout
    private let tileMaxWidth: CGFloat = 300
    private let gridSpacing: CGFloat = 12
    private let cornerRadius: CGFloat = 20

    private var columns: [GridItem] {
        [GridItem(.adaptive(minimum: 220, maximum: tileMaxWidth), spacing: gridSpacing, alignment: .top)]
    }

    private var allImages: [ImageAsset] { vm.newImages + vm.editedImages }
    private var isEmpty: Bool { allImages.isEmpty }

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ZStack { content }
            .padding(8)
            .frame(minWidth: 420)
            .contentShape(Rectangle())
            .dropDestination(for: URL.self, action: { urls, _ in
                handleURLDrop(urls)
            }, isTargeted: { hovering in
                handleDropHoverChange(hovering)
            })
            .dropDestination(for: NSImage.self, action: { images, _ in
                handleImageDrop(images)
            }, isTargeted: { hovering in
                handleDropHoverChange(hovering)
            })
    }

    private var content: some View {
        ZStack {
            if isEmpty {
                ImagesListEmptyState(
                    onPaste: { vm.addFromPasteboard() },
                    onPickFromFinder: onPickFromFinder
                )
            } else {
                ImagesGridView(
                    images: allImages,
                    vm: vm,
                    columns: columns
                )
            }
        }
        .background(containerBackground())
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .overlay(containerOverlay())
    }

    private func containerBackground() -> some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(Color.black.opacity(colorScheme == .dark ? 0.15 : 0.06))
    }

    private func containerOverlay() -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .stroke(Color.black.opacity(0.06), lineWidth: 0.5)

            if isEmpty || isDropping {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .inset(by: 8)
                    .stroke(style: StrokeStyle(lineWidth: 2, dash: [6, 6]))
                    .foregroundStyle(isDropping ? Color.accentColor.blendMode(.normal) : colorScheme == .dark ?  Color.white.opacity(0.25).blendMode(.lighten) : Color.black.opacity(0.20).blendMode(.darken))
            }
        }
        .allowsHitTesting(false)
    }

    private func handleDropHoverChange(_ hovering: Bool) {
        if hovering && !isDropping {
            performHapticFeedback()
        }
        isDropping = hovering
    }

    private func handleURLDrop(_ urls: [URL]) -> Bool {
        guard !urls.isEmpty else { return false }
        vm.addURLs(urls)
        return true
    }

    private func handleImageDrop(_ images: [NSImage]) -> Bool {
        guard !images.isEmpty else { return false }

        let tempDir = FileManager.default.temporaryDirectory
        var urls: [URL] = []
        for nsImage in images {
            guard
                let tiff = nsImage.tiffRepresentation,
                let rep = NSBitmapImageRep(data: tiff),
                let data = rep.representation(using: .png, properties: [:])
            else { continue }

            let url = tempDir.appendingPathComponent("drop_" + UUID().uuidString + ".png")
            try? data.write(to: url)
            urls.append(url)
        }
        guard !urls.isEmpty else { return false }
        vm.addURLs(urls)
        return true
    }

    private func performHapticFeedback() {
        NSHapticFeedbackManager.defaultPerformer.perform(.generic, performanceTime: .now)
    }
} 
