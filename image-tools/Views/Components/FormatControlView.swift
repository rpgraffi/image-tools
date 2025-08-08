import SwiftUI
import AppKit

struct FormatControlView: View {
    @ObservedObject var vm: ImageToolsViewModel
    @EnvironmentObject var dropdown: FormatDropdownController

    @FocusState private var searchFocused: Bool
    @State private var keyEventMonitor: Any?

    private let controlHeight: CGFloat = Theme.Metrics.controlHeight
    private let controlMinWidth: CGFloat = Theme.Metrics.controlMinWidth
    private let controlMaxWidth: CGFloat = Theme.Metrics.controlMaxWidth

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
                    Text(vm.selectedFormat?.displayName ?? "Format")
                        .foregroundStyle(.primary)
                        .font(.headline)
                }
                TextField("Format", text: $dropdown.query)
                    .textFieldStyle(.plain)
                    .font(.headline)
                    .opacity(dropdown.isOpen ? 1 : 0.01)
                    .focused($searchFocused)
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
        .frame(width: controlMaxWidth)
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
            let items = filteredAndSortedFormats()
            switch event.keyCode {
            case 125: // down
                if !items.isEmpty { dropdown.highlightedIndex = min(dropdown.highlightedIndex + 1, items.count - 1) }
                return nil
            case 126: // up
                if !items.isEmpty { dropdown.highlightedIndex = max(dropdown.highlightedIndex - 1, 0) }
                return nil
            case 36: // return
                if !items.isEmpty { select(items[max(0, min(dropdown.highlightedIndex, items.count - 1))]); return nil }
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

    fileprivate func select(_ fmt: ImageFormat) {
        vm.selectedFormat = fmt
        vm.bumpRecentFormats(fmt)
        withAnimation(Theme.Animations.spring()) { dropdown.isOpen = false; searchFocused = false }
        dropdown.query = ""
    }

    fileprivate func handleEnterSelection() {
        let items = filteredAndSortedFormats()
        if items.indices.contains(dropdown.highlightedIndex) { select(items[dropdown.highlightedIndex]) }
        else if let first = items.first { select(first) }
    }

    fileprivate func filteredAndSortedFormats() -> [ImageFormat] {
        let caps = ImageIOCapabilities.shared
        let all = ImageFormat.allCases.filter { caps.supportsWriting(utType: $0.utType) }
        let q = dropdown.query.trimmingCharacters(in: .whitespacesAndNewlines)
        if q.isEmpty {
            return all.sorted(by: { a, b in
                let ai = vm.recentFormats.firstIndex(of: a)
                let bi = vm.recentFormats.firstIndex(of: b)
                if ai != nil || bi != nil { return (ai ?? Int.max) < (bi ?? Int.max) }
                return a.displayName < b.displayName
            })
        }
        let lower = q.lowercased()
        let scored: [(fmt: ImageFormat, score: Int, recentRank: Int)] = all.compactMap { fmt in
            let name = fmt.displayName.lowercased()
            if let s = fuzzyScore(query: lower, candidate: name) {
                let recentRank = vm.recentFormats.firstIndex(of: fmt) ?? Int.max
                return (fmt, s, recentRank)
            }
            return nil
        }
        .sorted { (l, r) in
            if l.recentRank != r.recentRank { return l.recentRank < r.recentRank }
            if l.score != r.score { return l.score > r.score }
            return l.fmt.displayName < r.fmt.displayName
        }
        return scored.map { $0.fmt }
    }

    private func fuzzyScore(query: String, candidate: String) -> Int? {
        var score = 0
        var i = candidate.startIndex
        var prevMatch = candidate.startIndex
        for ch in query {
            if let idx = candidate[i...].firstIndex(of: ch) {
                if idx == prevMatch { score += 2 } else { score += 1 }
                prevMatch = candidate.index(after: idx)
                i = prevMatch
            } else { return nil }
        }
        return score
    }
}

// MARK: - Floating list content (used by MainView overlay)

struct FormatDropdownList: View {
    @ObservedObject var vm: ImageToolsViewModel
    @EnvironmentObject var dropdown: FormatDropdownController
    let onSelect: (ImageFormat) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            let items = filteredAndSortedFormats()
            if items.isEmpty {
                Text("No matches")
                    .foregroundStyle(.secondary)
                    .padding(8)
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
    private func listContent(items: [ImageFormat]) -> some View {
        VStack(spacing: 0) {
            ForEach(Array(items.enumerated()), id: \.element) { idx, fmt in
                Button(action: { onSelect(fmt) }) {
                    HStack {
                        Text(fmt.displayName)
                            .foregroundStyle(.primary)
                        Spacer()
                        if vm.recentFormats.contains(fmt) {
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
                            .opacity(fmt == vm.selectedFormat && idx != dropdown.highlightedIndex ? 1 : 0)
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

    private func filteredAndSortedFormats() -> [ImageFormat] {
        let caps = ImageIOCapabilities.shared
        let all = ImageFormat.allCases.filter { caps.supportsWriting(utType: $0.utType) }
        let q = dropdown.query.trimmingCharacters(in: .whitespacesAndNewlines)
        if q.isEmpty {
            return all.sorted(by: { a, b in
                let ai = vm.recentFormats.firstIndex(of: a)
                let bi = vm.recentFormats.firstIndex(of: b)
                if ai != nil || bi != nil { return (ai ?? Int.max) < (bi ?? Int.max) }
                return a.displayName < b.displayName
            })
        }
        let lower = q.lowercased()
        let scored: [(fmt: ImageFormat, score: Int, recentRank: Int)] = all.compactMap { fmt in
            let name = fmt.displayName.lowercased()
            if let s = fuzzyScore(query: lower, candidate: name) {
                let recentRank = vm.recentFormats.firstIndex(of: fmt) ?? Int.max
                return (fmt, s, recentRank)
            }
            return nil
        }
        .sorted { (l, r) in
            if l.recentRank != r.recentRank { return l.recentRank < r.recentRank }
            if l.score != r.score { return l.score > r.score }
            return l.fmt.displayName < r.fmt.displayName
        }
        return scored.map { $0.fmt }
    }

    private func fuzzyScore(query: String, candidate: String) -> Int? {
        var score = 0
        var i = candidate.startIndex
        var prevMatch = candidate.startIndex
        for ch in query {
            if let idx = candidate[i...].firstIndex(of: ch) {
                if idx == prevMatch { score += 2 } else { score += 1 }
                prevMatch = candidate.index(after: idx)
                i = prevMatch
            } else { return nil }
        }
        return score
    }
} 