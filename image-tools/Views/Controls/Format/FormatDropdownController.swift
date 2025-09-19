import Foundation
import SwiftUI
import UniformTypeIdentifiers

// Shared entry type for the format dropdown
enum FormatDropdownEntry: Identifiable, Equatable {
    case format(ImageFormat)

    var id: String {
        switch self {
        case .format(let f): return f.id
        }
    }

    var title: String {
        switch self {
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
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        let filteredFormats: [ImageFormat]
        if q.isEmpty {
            filteredFormats = allFormats
        } else {
            filteredFormats = allFormats.filter { $0.displayName.lowercased().contains(q) }
        }

        let sorted = filteredFormats.sorted(by: { a, b in
            let ai = vm.recentFormats.firstIndex(of: a)
            let bi = vm.recentFormats.firstIndex(of: b)
            if ai != nil || bi != nil { return (ai ?? Int.max) < (bi ?? Int.max) }
            return a.displayName < b.displayName
        })
        return sorted.map { .format($0) }
    }

} 