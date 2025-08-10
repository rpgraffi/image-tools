import SwiftUI
import UniformTypeIdentifiers
import AppKit

struct ImagesListView: View {
    @ObservedObject var vm: ImageToolsViewModel
    @Binding var isDropping: Bool
    let onPickFromFinder: () -> Void

    // Grid config
    private let tileMaxWidth: CGFloat = 300
    private var columns: [GridItem] { [GridItem(.adaptive(minimum: 220, maximum: tileMaxWidth), spacing: 12, alignment: .top)] }
    private var cornerRadius: CGFloat { 24 }

    private var allImages: [ImageAsset] { vm.newImages + vm.editedImages }
    private var isEmpty: Bool { allImages.isEmpty }

    var body: some View {
        ZStack { content }
            .padding(8)
            .frame(minWidth: 420)
            .contentShape(Rectangle())
            .dropDestination(for: URL.self, action: { urls, _ in
                handleURLDrop(urls)
            }, isTargeted: { hovering in
                isDropping = hovering
            })
            .dropDestination(for: NSImage.self, action: { images, _ in
                handleImageDrop(images)
            }, isTargeted: { hovering in
                isDropping = hovering
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
        .background(
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(Color.black.opacity(0.06))
        )
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .overlay(containerOverlay())
    }

    private func containerOverlay() -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .stroke(Color.black.opacity(0.06), lineWidth: 0.5)

            if isEmpty {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .inset(by: 16)
                    .stroke(style: StrokeStyle(lineWidth: 2, dash: [6, 6]))
                    .foregroundStyle(isDropping ? Color.accentColor.opacity(0.8) : Color.gray.opacity(0.5))
            }
        }
        .allowsHitTesting(false)
    }

    private func handleURLDrop(_ urls: [URL]) -> Bool {
        vm.addURLs(urls)
        return true
    }

    private func handleImageDrop(_ images: [NSImage]) -> Bool {
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
        vm.addURLs(urls)
        return true
    }
} 