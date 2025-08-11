import SwiftUI
import UniformTypeIdentifiers
import AppKit

struct FormatControl: View {
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
        vm.selectedFormat?.displayName ?? String(localized: "Format")
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
        let shape = Capsule()

        Menu {
            recentSection()
            pinnedSection()
            moreSection()
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "photo.on.rectangle.angled.fill")
                    .font(Theme.Fonts.button)
                    .foregroundStyle(vm.selectedFormat != nil ? Color.accentColor : .primary)

                Text(selectedLabel)
                    .foregroundStyle(.primary)
                    .font(Theme.Fonts.button)
            }
        }
        .menuStyle(.borderlessButton)
        .help(vm.selectedFormat?.fullName ?? "")
        .frame(height: controlHeight)
        .padding(.horizontal, 8)
        .background(shape.fill(Theme.Colors.controlBackground))
        .fixedSize(horizontal: true, vertical: false)
        .onAppear { installKeyMonitor() }
        .onDisappear { removeKeyMonitor() }
    }
}

// MARK: - Menu Builders
private extension FormatControl {
    @ViewBuilder
    func recentSection() -> some View {
        let pinnedIds = Set(pinnedFormats.map { $0.id })
        let recents = vm.recentFormats.filter { !pinnedIds.contains($0.id) }.prefix(3)
        if !recents.isEmpty {
            Section(String(localized: "Recent")) {
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
            Menu(String(localized: "More")) {
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
private extension FormatControl {
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

struct FormatControlView_Previews: PreviewProvider {
    static var previews: some View {
        let vmDefault = ImageToolsViewModel()
        let vmPNG: ImageToolsViewModel = {
            let v = ImageToolsViewModel()
            v.selectedFormat = ImageFormat(utType: .png)
            return v
        }()
        let vmJPEG: ImageToolsViewModel = {
            let v = ImageToolsViewModel()
            v.selectedFormat = ImageFormat(utType: .jpeg)
            return v
        }()

        return VStack(alignment: .leading, spacing: 16) {
            FormatControl(vm: vmDefault)
            FormatControl(vm: vmPNG)
            FormatControl(vm: vmJPEG)
        }
        .padding()
        .frame(width: 360)
    }
} 
