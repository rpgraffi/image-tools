import SwiftUI

struct Preset: Identifiable, Codable, Hashable {
    let id: UUID
    var name: String
    var data: Data // serialized pipeline intent (for now, just a placeholder)
}

final class PresetsStore: ObservableObject {
    @Published var presets: [Preset] = []

    func save(_ name: String, from vm: ImageToolsViewModel) {
        // Simplified: store current UI state as preset
        let encoder = JSONEncoder()
        struct Snapshot: Codable {
            var overwriteOriginals: Bool
            var sizeUnit: String
            var resizePercent: Double
            var resizeWidth: String
            var resizeHeight: String
            var selectedFormat: String?
            var compressionMode: String
            var compressionPercent: Double
            var compressionTargetKB: String
            var rotation: Int
            var flipH: Bool
            var flipV: Bool
            var removeBackground: Bool
        }
        let snap = Snapshot(
            overwriteOriginals: vm.overwriteOriginals,
            sizeUnit: vm.sizeUnit == .percent ? "percent" : "pixels",
            resizePercent: vm.resizePercent,
            resizeWidth: vm.resizeWidth,
            resizeHeight: vm.resizeHeight,
            selectedFormat: vm.selectedFormat?.rawValue,
            compressionMode: vm.compressionMode == .percent ? "percent" : "targetKB",
            compressionPercent: vm.compressionPercent,
            compressionTargetKB: vm.compressionTargetKB,
            rotation: vm.rotation.rawValue,
            flipH: vm.flipH,
            flipV: vm.flipV,
            removeBackground: vm.removeBackground
        )
        if let data = try? encoder.encode(snap) {
            let preset = Preset(id: UUID(), name: name, data: data)
            presets.append(preset)
        }
    }

    func apply(_ preset: Preset, to vm: ImageToolsViewModel) {
        let decoder = JSONDecoder()
        struct Snapshot: Codable { // keep in sync with save
            var overwriteOriginals: Bool
            var sizeUnit: String
            var resizePercent: Double
            var resizeWidth: String
            var resizeHeight: String
            var selectedFormat: String?
            var compressionMode: String
            var compressionPercent: Double
            var compressionTargetKB: String
            var rotation: Int
            var flipH: Bool
            var flipV: Bool
            var removeBackground: Bool
        }
        guard let snap = try? decoder.decode(Snapshot.self, from: preset.data) else { return }
        vm.overwriteOriginals = snap.overwriteOriginals
        vm.sizeUnit = snap.sizeUnit == "percent" ? .percent : .pixels
        vm.resizePercent = snap.resizePercent
        vm.resizeWidth = snap.resizeWidth
        vm.resizeHeight = snap.resizeHeight
        vm.selectedFormat = snap.selectedFormat.flatMap { ImageFormat(rawValue: $0) }
        vm.compressionMode = snap.compressionMode == "percent" ? .percent : .targetKB
        vm.compressionPercent = snap.compressionPercent
        vm.compressionTargetKB = snap.compressionTargetKB
        vm.rotation = ImageRotation(rawValue: snap.rotation) ?? .r0
        vm.flipH = snap.flipH
        vm.flipV = snap.flipV
        vm.removeBackground = snap.removeBackground
    }
}

struct PresetsView: View {
    @ObservedObject var store: PresetsStore
    var onApply: (Preset) -> Void

    var body: some View {
        VStack(alignment: .leading) {
            HStack {
                Text("Presets").font(.headline)
                Spacer()
            }
            List(store.presets) { preset in
                HStack {
                    Text(preset.name)
                    Spacer()
                    Button("Apply") { onApply(preset) }
                }
            }
        }
        .padding(8)
    }
} 