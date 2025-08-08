import SwiftUI

struct ImageRow: View {
    let asset: ImageAsset
    let isEdited: Bool
    @ObservedObject var vm: ImageToolsViewModel
    let toggle: () -> Void
    let recover: (() -> Void)?

    var body: some View {
        let preview = vm.previewInfo(for: asset)
        HStack(spacing: 12) {
            if let t = asset.thumbnail {
                Image(nsImage: t)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 36, height: 36)
                    .cornerRadius(4)
            } else {
                Rectangle().fill(Color.gray.opacity(0.2)).frame(width: 36, height: 36).cornerRadius(4)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(asset.workingURL.lastPathComponent).font(.callout)
                Text(asset.workingURL.deletingLastPathComponent().path)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                HStack(spacing: 8) {
                    if let original = asset.originalPixelSize {
                        Text("orig: \(Int(original.width))×\(Int(original.height)))")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    if let target = preview.targetPixelSize {
                        Text("→ \(Int(target.width))×\(Int(target.height)))")
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
            Toggle(isOn: .constant(asset.isEnabled)) { EmptyView() }
                .toggleStyle(.checkbox)
                .onChange(of: asset.isEnabled) { _, _ in toggle() }
                .help("Enable/Disable for batch")
        }
        .contentShape(Rectangle())
        .overlay(alignment: .trailing) {
            if let recover {
                Button(action: recover) { Image(systemName: "clock.arrow.circlepath") }
                    .buttonStyle(.plain)
                    .padding(.trailing, 4)
                    .help("Recover original")
            }
        }
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