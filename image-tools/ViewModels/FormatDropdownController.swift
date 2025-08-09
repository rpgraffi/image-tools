import Foundation
import SwiftUI
import UniformTypeIdentifiers

// Shared entry type for the format dropdown
enum FormatDropdownEntry: Identifiable, Equatable {
    case original
    case format(ImageFormat)

    var id: String {
        switch self {
        case .original: return "__original__"
        case .format(let f): return f.id
        }
    }

    var title: String {
        switch self {
        case .original: return "Original"
        case .format(let f): return f.displayName
        }
    }
}

final class FormatDropdownController: ObservableObject {
    @Published var isOpen: Bool = false
    @Published var query: String = ""
    @Published var highlightedIndex: Int = 0
}

// MARK: - Filtering & Ranking logic
extension FormatDropdownController {
    func filteredAndSortedEntries(vm: ImageToolsViewModel) -> [FormatDropdownEntry] {
        let allFormats = ImageIOCapabilities.shared.writableFormats()
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines)
        if q.isEmpty {
            let sorted = allFormats.sorted(by: { a, b in
                let ai = vm.recentFormats.firstIndex(of: a)
                let bi = vm.recentFormats.firstIndex(of: b)
                if ai != nil || bi != nil { return (ai ?? Int.max) < (bi ?? Int.max) }
                return a.displayName < b.displayName
            })
            return [.original] + sorted.map { .format($0) }
        }
        let lower = q.lowercased()
        var entries: [(entry: FormatDropdownEntry, score: Int, recentRank: Int)] = []
        for fmt in allFormats {
            let name = fmt.displayName.lowercased()
            if let s = fuzzyScore(query: lower, candidate: name) {
                let recentRank = vm.recentFormats.firstIndex(of: fmt) ?? Int.max
                entries.append((.format(fmt), s, recentRank))
            }
        }
        if let s = fuzzyScore(query: lower, candidate: "original") {
            entries.append((.original, s, Int.max))
        }
        let sorted = entries.sorted { l, r in
            if l.recentRank != r.recentRank { return l.recentRank < r.recentRank }
            if l.score != r.score { return l.score > r.score }
            return l.entry.title < r.entry.title
        }
        return sorted.map { $0.entry }
    }

    /// Very lightweight fuzzy score that rewards consecutive matches.
    func fuzzyScore(query: String, candidate: String) -> Int? {
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