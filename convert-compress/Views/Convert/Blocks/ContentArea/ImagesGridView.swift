import SwiftUI
import AppKit

struct ImagesGridView: View {
    @EnvironmentObject private var vm: ImageToolsViewModel
    let images: [ImageAsset]
    let columns: [GridItem]
    let heroNamespace: Namespace.ID
    @State private var visibleIds: Set<UUID> = []
    @State private var debounceWorkItem: DispatchWorkItem? = nil
    @State private var appearedIds: Set<UUID> = []
    
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
                        heroNamespace: heroNamespace
                    )
                    .aspectRatio(1, contentMode: .fit)
                    .opacity(appearedIds.contains(asset.id) ? 1 : 0)
                    .scaleEffect(appearedIds.contains(asset.id) ? 1 : 0.94)
                    .animation(.spring(response: 0.45, dampingFraction: 0.75), value: appearedIds.contains(asset.id))
                    .onTapGesture { 
                        vm.presentComparison(for: asset) 
                    }
                    .onAppear {
                        visibleIds.insert(asset.id)
                        scheduleEstimation()
                        // Trigger animation with slight delay for stagger effect
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.02) {
                            appearedIds.insert(asset.id)
                        }
                    }
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
        
        return PreviewWrapper(assets: assets, columns: columns, vm: vm)
    }
    
    private struct PreviewWrapper: View {
        let assets: [ImageAsset]
        let columns: [GridItem]
        let vm: ImageToolsViewModel
        @Namespace private var heroNamespace
        
        var body: some View {
            ImagesGridView(images: assets, columns: columns, heroNamespace: heroNamespace)
                .environmentObject(vm)
                .frame(width: 900, height: 600)
                .padding()
        }
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
