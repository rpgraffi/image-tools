import SwiftUI
import UniformTypeIdentifiers
import AppKit

struct FormatControlView: View {
    @ObservedObject var vm: ImageToolsViewModel

    private let controlHeight: CGFloat = Theme.Metrics.controlHeight

    @State private var keyEventMonitor: Any?

    private var pinnedFormats: [ImageFormat] {
        [ImageFormat(utType: .png), ImageFormat(utType: .jpeg), ImageFormat(utType: .heic)]
            .filter { ImageIOCapabilities.shared.supportsWriting(utType: $0.utType) }
    }

    private var otherFormats: [ImageFormat] {
        let pinnedIds = Set(pinnedFormats.map { $0.id })
        return ImageIOCapabilities.shared
            .writableFormats()
            .filter { !pinnedIds.contains($0.id) }
            .sorted { $0.displayName < $1.displayName }
    }

    private var selectedLabel: String {
        vm.selectedFormat?.displayName ?? "Original"
    }

    private func shortcutFor(format: ImageFormat) -> String? {
        switch format.utType {
        case .png: return "P"
        case .jpeg: return "J"
        case .heic: return "H"
        default: return nil
        }
    }

    private func selectFormat(_ format: ImageFormat?) {
        vm.selectedFormat = format
        if let f = format { vm.bumpRecentFormats(f) }
    }

    var body: some View {
        let topCorner = controlHeight / 2
        let shape = UnevenRoundedRectangle(
            cornerRadii: .init(
                topLeading: topCorner,
                bottomLeading: topCorner,
                bottomTrailing: topCorner,
                topTrailing: topCorner
            ),
            style: .continuous
        )

        // Pill with Menu inside
        HStack(spacing: 8) {
            Image(systemName: "photo.on.rectangle.angled.fill")
                .font(.headline)
                .foregroundStyle(vm.selectedFormat != nil ? Color.accentColor : .primary)

            Menu {
                originalItem()
                recentSection()
                pinnedSection()
                moreSection()
            } label: {
                Text(selectedLabel)
                    .foregroundStyle(.primary)
                    .font(.headline)
            }
            .menuStyle(.borderlessButton)
            .help(vm.selectedFormat?.fullName ?? "Keep original format")
        }
        .frame(height: controlHeight)
        .padding(.horizontal, 12)
        .contentShape(Rectangle())
        .background(shape.fill(Theme.Colors.controlBackground))
        .clipShape(shape)
        .fixedSize(horizontal: true, vertical: false)
        .onAppear { installKeyMonitor() }
        .onDisappear { removeKeyMonitor() }
        .animation(.spring(response: 0.6, dampingFraction: 0.85), value: selectedLabel)
    }
}

// MARK: - Menu Builders
private extension FormatControlView {
    @ViewBuilder
    func originalItem() -> some View {
        Button("Original") { selectFormat(nil) }
            .help("Keep original format")
    }

    @ViewBuilder
    func recentSection() -> some View {
        let pinnedIds = Set(pinnedFormats.map { $0.id })
        let recents = vm.recentFormats.filter { !pinnedIds.contains($0.id) }.prefix(3)
        if !recents.isEmpty {
            Section("Recent") {
                ForEach(Array(recents), id: \.id) { f in
                    Button(f.displayName) { selectFormat(f) }
                        .help(f.fullName)
                }
            }
        }
    }

    @ViewBuilder
    func pinnedSection() -> some View {
        Section {
            ForEach(pinnedFormats, id: \.id) { f in
                pinnedRowButton(f)
            }
        }
    }

    @ViewBuilder
    func moreSection() -> some View {
        if !otherFormats.isEmpty {
            Menu("More") {
                ForEach(otherFormats, id: \.id) { f in
                    Button(f.displayName) { selectFormat(f) }
                        .help(f.fullName)
                }
            }
        }
    }

    @ViewBuilder
    func pinnedRowButton(_ f: ImageFormat) -> some View {
        if f.utType == .png {
            Button(f.displayName) { selectFormat(f) }
                .keyboardShortcut(.init("p"), modifiers: [])
                .help(f.fullName)
        } else if f.utType == .jpeg {
            Button(f.displayName) { selectFormat(f) }
                .keyboardShortcut(.init("j"), modifiers: [])
                .help(f.fullName)
        } else if f.utType == .heic {
            Button(f.displayName) { selectFormat(f) }
                .keyboardShortcut(.init("h"), modifiers: [])
                .help(f.fullName)
        }
    }
}

// MARK: - Keyboard Handling
private extension FormatControlView {
    func installKeyMonitor() {
        removeKeyMonitor()
        keyEventMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            guard let chars = event.charactersIgnoringModifiers?.lowercased(), event.modifierFlags.intersection([.command, .option, .control]).isEmpty else {
                return event
            }
            switch chars {
            case "p":
                if let fmt = pinnedFormats.first(where: { $0.utType == .png }) { selectFormat(fmt); return nil }
            case "j":
                if let fmt = pinnedFormats.first(where: { $0.utType == .jpeg }) { selectFormat(fmt); return nil }
            case "h":
                if let fmt = pinnedFormats.first(where: { $0.utType == .heic }) { selectFormat(fmt); return nil }
            default:
                break
            }
            return event
        }
    }

    func removeKeyMonitor() {
        if let monitor = keyEventMonitor { NSEvent.removeMonitor(monitor); keyEventMonitor = nil }
    }
} 