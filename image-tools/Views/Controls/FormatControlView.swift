import SwiftUI
import AppKit

struct FormatControlView: View {
    @ObservedObject var vm: ImageToolsViewModel
    @EnvironmentObject var dropdown: FormatDropdownController

    @FocusState private var searchFocused: Bool
    @State private var keyEventMonitor: Any?

    private let controlHeight: CGFloat = Theme.Metrics.controlHeight
    private let controlMinWidth: CGFloat = Theme.Metrics.controlMinWidth
    private let controlMaxWidth: CGFloat = 140

    var body: some View {
        let topCorner = controlHeight / 2
        let shape = UnevenRoundedRectangle(
            cornerRadii: .init(
                topLeading: topCorner,
                bottomLeading: dropdown.isOpen ? 10 : topCorner,
                bottomTrailing: dropdown.isOpen ? 10 : topCorner,
                topTrailing: topCorner
            ),
            style: .continuous
        )

        // Header pill (fixed height)
        HStack(spacing: 8) {
            Image(systemName: "photo.on.rectangle.angled.fill")
                .font(.headline)
                .foregroundStyle(.secondary)
            ZStack(alignment: .leading) {
                if (dropdown.query.isEmpty && !dropdown.isOpen) {
                    Text(vm.selectedFormat == nil ? "Original" : (vm.selectedFormat?.displayName ?? "Format"))
                        .foregroundStyle(.primary)
                        .font(.headline)
                }
                TextField("Format", text: $dropdown.query)
                    .textFieldStyle(.plain)
                    .font(.headline)
                    .opacity(dropdown.isOpen ? 1 : 0.01)
                    .focused($searchFocused)
                    .disabled(!dropdown.isOpen)
                    .allowsHitTesting(dropdown.isOpen)
                    .onChange(of: searchFocused) { _, focused in
                        if !focused { withAnimation(Theme.Animations.spring()) { dropdown.isOpen = false } }
                    }
                    .onSubmit { handleEnterSelection() }
            }
        }
        .frame(height: controlHeight)
        .padding(.horizontal, 12)
        .contentShape(Rectangle())
        .onTapGesture { withAnimation(Theme.Animations.spring()) { dropdown.isOpen = true }; searchFocused = true; dropdown.highlightedIndex = 0 }
        .background(shape.fill(Theme.Colors.controlBackground))
        .clipShape(shape)
        .frame(minWidth: controlMinWidth, maxWidth: controlMaxWidth)
        .animation(Theme.Animations.spring(), value: dropdown.isOpen)
        .onAppear { dropdown.query = "" }
        .onChange(of: dropdown.query) { _, _ in dropdown.highlightedIndex = 0 }
        .onChange(of: dropdown.isOpen) { _, open in open ? installKeyMonitor() : removeKeyMonitor() }
        .onExitCommand { withAnimation(Theme.Animations.spring()) { dropdown.isOpen = false; searchFocused = false } }
        .anchorPreference(key: FormatDropdownAnchorKey.self, value: .bounds) { anchor in
            dropdown.isOpen ? anchor : nil
        }
    }

    // MARK: - Keyboard & Selection helpers

    private func installKeyMonitor() {
        removeKeyMonitor()
        keyEventMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            let items = dropdown.filteredAndSortedEntries(vm: vm)
            switch event.keyCode {
            case 125: // down
                if !items.isEmpty { dropdown.highlightedIndex = min(dropdown.highlightedIndex + 1, items.count - 1) }
                return nil
            case 126: // up
                if !items.isEmpty { dropdown.highlightedIndex = max(dropdown.highlightedIndex - 1, 0) }
                return nil
            case 36: // return
                if !items.isEmpty {
                    let idx = max(0, min(dropdown.highlightedIndex, items.count - 1))
                    let entry = items[idx]
                    switch entry {
                    case .original: select(nil)
                    case .format(let f): select(f)
                    }
                    return nil
                }
                return event
            case 53: // esc
                withAnimation(Theme.Animations.spring()) { dropdown.isOpen = false; searchFocused = false }
                return nil
            default:
                return event
            }
        }
    }

    private func removeKeyMonitor() {
        if let monitor = keyEventMonitor { NSEvent.removeMonitor(monitor); keyEventMonitor = nil }
    }

    fileprivate func select(_ fmt: ImageFormat?) {
        vm.selectedFormat = fmt
        if let f = fmt { vm.bumpRecentFormats(f) }
        withAnimation(Theme.Animations.spring()) { dropdown.isOpen = false; searchFocused = false }
        dropdown.query = ""
    }

    fileprivate func handleEnterSelection() {
        let items = dropdown.filteredAndSortedEntries(vm: vm)
        if items.indices.contains(dropdown.highlightedIndex) {
            let entry = items[dropdown.highlightedIndex]
            switch entry { case .original: select(nil); case .format(let f): select(f) }
        } else if let first = items.first {
            switch first { case .original: select(nil); case .format(let f): select(f) }
        }
    }
}

// MARK: - Floating list content (used by MainView overlay)

struct FormatDropdownList: View {
    @ObservedObject var vm: ImageToolsViewModel
    @EnvironmentObject var dropdown: FormatDropdownController
    let onSelect: (ImageFormat?) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            let items = dropdown.filteredAndSortedEntries(vm: vm)
            if items.isEmpty {
                Text("No matches")
                    .foregroundStyle(.secondary)
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                ViewThatFits(in: .vertical) {
                    // Non-scroll variant: hugs content height
                    listContent(items: items)
                    // Scroll variant if content exceeds max height
                    ScrollViewReader { proxy in
                        ScrollView {
                            listContent(items: items)
                        }
                        .frame(maxHeight: 500)
                        .onChange(of: dropdown.highlightedIndex) { _, newValue in
                            withAnimation(Theme.Animations.spring()) { proxy.scrollTo(newValue, anchor: .center) }
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func listContent(items: [FormatDropdownEntry]) -> some View {
        VStack(spacing: 0) {
            ForEach(Array(items.enumerated()), id: \.element.id) { idx, entry in
                Button(action: {
                    switch entry { case .original: onSelect(nil); case .format(let f): onSelect(f) }
                }) {
                    HStack {
                        Text(entry.title)
                            .foregroundStyle(.primary)
                        Spacer()
                        if case .format(let f) = entry, vm.recentFormats.contains(f) {
                            Text("recent")
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .contentShape(Rectangle())
                    .background(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(Color.accentColor.opacity(0.14))
                            .opacity(idx == dropdown.highlightedIndex ? 1 : 0)
                            .allowsHitTesting(false)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(Color.accentColor.opacity(0.08))
                            .opacity({
                                switch entry {
                                case .original: return vm.selectedFormat == nil && idx != dropdown.highlightedIndex
                                case .format(let f): return vm.selectedFormat == f && idx != dropdown.highlightedIndex
                                }
                            }() ? 1 : 0)
                            .allowsHitTesting(false)
                    )
                }
                .buttonStyle(.plain)
                .frame(maxWidth: .infinity) // Expand button hit area to full row
                .contentShape(Rectangle())
                .id(idx)
                .onHover { hovering in if hovering { dropdown.highlightedIndex = idx } }
            }
        }
        .padding(6)
    }
} 