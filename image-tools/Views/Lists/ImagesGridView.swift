import SwiftUI
import AppKit

struct ImagesGridView: View {
    @EnvironmentObject var vm: ImageToolsViewModel
    let images: [ImageAsset]
    let columns: [GridItem]
    @State private var visibleIds: Set<UUID> = []
    @State private var debounceWorkItem: DispatchWorkItem? = nil

    private func scheduleEstimation() {
        debounceWorkItem?.cancel()
        let work = DispatchWorkItem { [visibleIds, images] in
            let visible = images.filter { visibleIds.contains($0.id) }
            vm.triggerEstimationForVisible(visible)
        }
        debounceWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15, execute: work)
    }

    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(images) { asset in
                    ImageItem(
                        asset: asset,
                        vm: vm,
                        recover: asset.backupURL != nil ? { vm.recoverOriginal(asset) } : nil
                    )
                    .aspectRatio(1, contentMode: .fit)
                    .onAppear { visibleIds.insert(asset.id); scheduleEstimation() }
                    .onDisappear { visibleIds.remove(asset.id); scheduleEstimation() }
                }
            }
            .padding(10)
        }
        .scrollContentBackground(.hidden)
    }
}

struct ImagesGridView_Previews: PreviewProvider {
    static var previews: some View {
        let vm = ImageToolsViewModel()
        let urls: [URL] = [
            makeTempImageURL(size: NSSize(width: 640, height: 360), color: .systemBlue),
            makeTempImageURL(size: NSSize(width: 800, height: 800), color: .systemGreen),
            makeTempImageURL(size: NSSize(width: 600, height: 1200), color: .systemOrange)
        ]
        let assets = urls.map { ImageAsset(url: $0) }
        let columns = [GridItem(.adaptive(minimum: 220, maximum: 300), spacing: 12, alignment: .top)]

        return ImagesGridView(images: assets, columns: columns)
            .environmentObject(vm)
            .frame(width: 900, height: 600)
            .padding()
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
