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
        let strokeColorDark = LinearGradient(colors: [Color.white.opacity(0.08), Color.white.opacity(0.15)], startPoint: .top, endPoint: .bottom)
        let strokeColorLight = LinearGradient(colors: [Color.black.opacity(0.08), Color.white.opacity(0.32)], startPoint: .top, endPoint: .bottom)
        return ZStack {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .stroke(colorScheme == .dark ? strokeColorDark : strokeColorLight, lineWidth: 0.8)

            // Inner shadow: bottom shade
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .stroke(Color.black.opacity(colorScheme == .dark ? 0.60 : 0.20), lineWidth: 1.5)
                .blur(radius: 6)
                .offset(y: 3)
                .mask(
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        // .fill(
                        //     LinearGradient(colors: [Color.black, Color.clear], startPoint: .center, endPoint: .bottom)
                        // )
                )

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

struct ImagesListView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            // Empty state
            ImagesListView(
                vm: demoVMEmpty(),
                isDropping: .constant(false),
                onPickFromFinder: {}
            )
            .frame(width: 900, height: 600)
            .padding()

            // With images
            ImagesListView(
                vm: demoVMWithImages(),
                isDropping: .constant(false),
                onPickFromFinder: {}
            )
            .frame(width: 900, height: 600)
            .padding()

            // Dropping state + dark mode
            ImagesListView(
                vm: demoVMWithImages(),
                isDropping: .constant(true),
                onPickFromFinder: {}
            )
            .frame(width: 900, height: 600)
            .padding()
            .preferredColorScheme(.dark)
        }
    }

    private static func demoVMEmpty() -> ImageToolsViewModel {
        ImageToolsViewModel()
    }

    private static func demoVMWithImages() -> ImageToolsViewModel {
        let vm = ImageToolsViewModel()
        let urls: [URL] = [
            makeTempImageURL(size: NSSize(width: 640, height: 360), color: .systemBlue),
            makeTempImageURL(size: NSSize(width: 800, height: 800), color: .systemGreen),
            makeTempImageURL(size: NSSize(width: 600, height: 1200), color: .systemOrange)
        ]
        vm.newImages = urls.map { ImageAsset(url: $0) }
        return vm
    }

    private static func makeTempImageURL(size: NSSize, color: NSColor) -> URL {
        let image = NSImage(size: size)
        image.lockFocus()
        color.setFill()
        NSBezierPath(rect: NSRect(origin: .zero, size: size)).fill()
        image.unlockFocus()
        guard let tiff = image.tiffRepresentation,
              let rep = NSBitmapImageRep(data: tiff),
              let data = rep.representation(using: .png, properties: [:]) else {
            return FileManager.default.temporaryDirectory.appendingPathComponent("preview_\(UUID().uuidString).png")
        }
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("preview_\(UUID().uuidString).png")
        try? data.write(to: url)
        return url
    }
}
